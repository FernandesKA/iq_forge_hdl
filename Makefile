TOP        := dds_tx_chain_tb
SNAPSHOT   := $(TOP)_sim

RTL_SRCS   := $(wildcard rtl/*.sv rtl/*/*.sv)
SIM_SRCS   := $(wildcard sim/*.sv)
ALL_SRCS   := $(RTL_SRCS) $(SIM_SRCS)
SINE_LUT_HEX := rtl/dds/sine_lut.hex
# xsim's $readmemh (bare "sine_lut.hex" in sine_lut.sv, kept path-less so
# Vivado synthesis resolves it next to the source) only searches the cwd or
# xsim.dir's parent at runtime -- neither is rtl/dds/, so mirror the file
# here for simulation.
SIM_HEX    := sine_lut.hex
GLBL       := $(XILINX_VIVADO)/data/verilog/src/glbl.v

.PHONY: all sim sim_gui compile elaborate clean check

all: sim

check:
	./check.sh

$(SINE_LUT_HEX): scripts/gen_sine_lut.py
	python3 scripts/gen_sine_lut.py

$(SIM_HEX): $(SINE_LUT_HEX)
	cp $(SINE_LUT_HEX) $(SIM_HEX)

compile: $(ALL_SRCS) $(SINE_LUT_HEX)
	xvlog -sv $(ALL_SRCS)
	xvlog -sv $(GLBL)

elaborate: compile
	xelab $(TOP) glbl -s $(SNAPSHOT) -L unisims_ver -L unimacro_ver

sim: elaborate $(SIM_HEX)
	xsim $(SNAPSHOT) -runall

sim_gui: elaborate $(SIM_HEX)
	xsim $(SNAPSHOT) -gui

clean:
	rm -rf xsim.dir *.jou *.log *.pb *.wdb .Xil xelab.pb webtalk*.jou webtalk*.log $(SINE_LUT_HEX) $(SIM_HEX)