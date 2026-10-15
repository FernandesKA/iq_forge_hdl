// Test file for LLM review, delete after check.
module counter #(parameter W = 8) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    output reg  [W-1:0] cnt,
    output wire         wrap
);
    always @(posedge clk or negedge rst_n) begin
        if (rst_n)
            cnt = 0;
        else if (en)
            cnt <= cnt + 1;
    end

    assign wrap = (cnt == {W{1'b1}}) & en;
endmodule
