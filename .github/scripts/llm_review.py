#!/usr/bin/env python3
"""Review a GitHub pull request with an LLM (local Ollama or an OpenAI-compatible API).

Reads the PR diff through the GitHub API (PR code is never checked out or
executed), asks the model to review it file by file, and posts the result as
a single PR comment that is updated in place on every new push.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, PR_NUMBER
     LLM_BACKEND: ollama (default) or openai
     ollama: OLLAMA_URL (default http://localhost:11434), LLM_MODEL (default qwen3-coder)
     openai: LLM_URL (base URL, e.g. https://openrouter.ai/api/v1 or
             https://api.deepseek.com), LLM_API_KEY, LLM_MODEL (required)
Local test without GitHub: llm_review.py --diff-file some.diff
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

MARKER = "<!-- llm-review -->"
BACKEND = os.environ.get("LLM_BACKEND", "ollama")
MODEL = os.environ.get("LLM_MODEL") or os.environ.get("OLLAMA_MODEL") or "qwen3-coder"
# Chars per request; bigger patches are split. ~24K chars fits the 16K-token
# context set for Ollama below; hosted APIs have larger windows.
MAX_FILE_PATCH = int(os.environ.get("LLM_MAX_PATCH", 24_000))
MAX_FILES = 40
SKIP_RE = re.compile(
    r"(\.lock$|package-lock\.json$|\.min\.(js|css)$|\.svg$|\.bin$|\.bit$|"
    r"\.(png|jpe?g|gif|pdf|zip|gz)$|^third_party/|/generated/)"
)

PROMPT = """You are a senior embedded / FPGA / systems engineer doing code review.
Review ONLY the diff below for file `{path}`. Look for: bugs, wrong logic,
off-by-one, race conditions, memory/resource leaks, undefined behavior,
security issues, wrong register/bit handling, broken error handling.
Ignore pure style nits unless they hide a bug.

Answer in Russian, as a short markdown list. Each item: line reference from the
diff (+ side), severity [critical|major|minor], the problem and a concrete fix.
If there is nothing worth mentioning, answer exactly: OK

PR title: {title}

```diff
{patch}
```"""


def gh(method, path, body=None):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    # The runner's route to api.github.com drops out now and then: retry
    # network errors and 5xx, fail at once on 4xx.
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read() or b"null")
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == 4:
                raise
            err = e
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if attempt == 4:
                raise
            err = e
        print(f"  GitHub API {method} {path}: {err}, retry {attempt + 1}/4",
              file=sys.stderr)
        time.sleep(10 * 2 ** attempt)


def gh_paged(path):
    out, page = [], 1
    while True:
        chunk = gh("GET", f"{path}{'&' if '?' in path else '?'}per_page=100&page={page}")
        out += chunk
        if len(chunk) < 100:
            return out
        page += 1


class QuotaExceeded(Exception):
    pass


def openai_compat(prompt):
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 1500,
    }
    req = urllib.request.Request(
        os.environ["LLM_URL"].rstrip("/") + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {os.environ['LLM_API_KEY']}",
            "Content-Type": "application/json",
        },
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                raw = r.read()
            try:
                return json.loads(raw)["choices"][0]["message"]["content"]
            except (ValueError, KeyError, IndexError):
                raise RuntimeError(f"{MODEL}: unexpected response {raw[:200]!r}") from None
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500:
                raise
            # Per-minute limit: wait it out. Daily limit: Retry-After is hours.
            wait = int(e.headers.get("Retry-After") or 30 * 2 ** attempt)
            if e.code == 429 and wait > 120:
                raise QuotaExceeded(f"{MODEL}: лимит запросов, retry через {wait} с")
            if attempt == 3:
                raise
            print(f"  {MODEL}: HTTP {e.code}, sleep {wait}s", file=sys.stderr)
            time.sleep(wait)


def ollama(prompt):
    url = os.environ.get("OLLAMA_URL", "http://localhost:11434").rstrip("/")
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
        "options": {"temperature": 0.2, "num_ctx": 16384, "num_predict": 1500,
                    "repeat_penalty": 1.1},
    }
    req = urllib.request.Request(f"{url}/api/chat", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        text = json.loads(r.read())["message"]["content"]
    return text


def ask(prompt):
    text = (openai_compat if BACKEND == "openai" else ollama)(prompt)
    # Drop reasoning blocks some models emit.
    return re.sub(r"<think>.*?</think>", "", text or "", flags=re.S).strip()


def split_patch(patch):
    if len(patch) <= MAX_FILE_PATCH:
        return [patch]
    parts, cur = [], ""
    for hunk in re.split(r"(?m)^(?=@@ )", patch):
        if cur and len(cur) + len(hunk) > MAX_FILE_PATCH:
            parts.append(cur)
            cur = ""
        cur += hunk[:MAX_FILE_PATCH]
    return parts + [cur] if cur else parts


def parse_diff_file(path):
    """Turn a plain `git diff` into the [{filename, patch}] shape of the API."""
    files = []
    for block in re.split(r"(?m)^diff --git ", open(path).read())[1:]:
        m = re.search(r"(?m)^\+\+\+ b/(.+)$", block)
        if not m:
            continue
        start = block.find("\n@@")
        files.append({"filename": m.group(1), "status": "modified",
                      "patch": block[start + 1:] if start >= 0 else ""})
    return files


def review(files, title):
    sections, skipped, quota = [], [], None
    for f in files[:MAX_FILES]:
        name, patch = f["filename"], f.get("patch") or ""
        if quota or f.get("status") == "removed" or not patch or SKIP_RE.search(name) \
                or patch.lstrip("@ -+0-9,\n").startswith("Subproject commit"):
            skipped.append(name)
            continue
        notes = []
        for part in split_patch(patch):
            t0 = time.time()
            try:
                ans = ask(PROMPT.format(path=name, title=title, patch=part))
            except QuotaExceeded as e:
                quota = str(e)
                print(f"  {quota}", file=sys.stderr)
                break
            ans = re.sub(r"\n+\W*OK\W*$", "", ans)
            print(f"  {name}: {time.time() - t0:.0f}s", file=sys.stderr)
            if re.sub(r"[\s*`_.!]", "", ans).upper() != "OK":
                notes.append(ans)
        if quota:
            skipped.append(name + (" (частично)" if notes else ""))
        if notes:
            sections.append(f"### `{name}`\n" + "\n\n".join(notes))
    skipped += [f["filename"] for f in files[MAX_FILES:]]
    return sections, skipped, quota


def render(sections, skipped, quota, sha, model):
    body = [MARKER, f"## 🤖 LLM review (`{model}`, {sha[:7]})", ""]
    if quota:
        body += [f"> ⚠️ Ревью неполное: {quota}. Перезапусти workflow позже.", ""]
    body += sections or ["Замечаний нет."]
    if skipped:
        body += ["", "<details><summary>Не проверялось: "
                 f"{len(skipped)} файл(ов)</summary>\n\n"
                 + "\n".join(f"- `{s}`" for s in skipped) + "\n</details>"]
    body += ["", "_Автоматическое ревью LLM: возможны ложные срабатывания._"]
    return "\n".join(body)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--diff-file", help="review a local diff and print, no GitHub")
    args = ap.parse_args()

    if args.diff_file:
        result = review(parse_diff_file(args.diff_file), "local test")
        print(render(*result, "local00", MODEL))
        return

    repo, num = os.environ["GITHUB_REPOSITORY"], os.environ["PR_NUMBER"]
    pr = gh("GET", f"/repos/{repo}/pulls/{num}")
    files = gh_paged(f"/repos/{repo}/pulls/{num}/files")
    body = render(*review(files, pr["title"]), pr["head"]["sha"], MODEL)

    mine = [c for c in gh_paged(f"/repos/{repo}/issues/{num}/comments")
            if MARKER in (c.get("body") or "")]
    if mine:
        gh("PATCH", f"/repos/{repo}/issues/comments/{mine[-1]['id']}", {"body": body})
    else:
        gh("POST", f"/repos/{repo}/issues/{num}/comments", {"body": body})
    print(f"review posted to {repo}#{num}", file=sys.stderr)


if __name__ == "__main__":
    main()
