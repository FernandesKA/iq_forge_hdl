TOP        := phase_acc_tb
SNAPSHOT   := $(TOP)_sim

RTL_SRCS   := $(wildcard rtl/*.sv)
SIM_SRCS   := $(wildcard sim/*.sv)
ALL_SRCS   := $(RTL_SRCS) $(SIM_SRCS)
SINE_LUT_HEX := rtl/sine_lut.hex

.PHONY: all sim sim_gui compile elaborate clean

all: sim

$(SINE_LUT_HEX): scripts/gen_sine_lut.py
	python3 scripts/gen_sine_lut.py

compile: $(ALL_SRCS) $(SINE_LUT_HEX)
	xvlog -sv $(ALL_SRCS)

elaborate: compile
	xelab $(TOP) -s $(SNAPSHOT)

sim: elaborate
	xsim $(SNAPSHOT) -runall

sim_gui: elaborate
	xsim $(SNAPSHOT) -gui

clean:
	rm -rf xsim.dir *.jou *.log *.pb *.wdb .Xil xelab.pb webtalk*.jou webtalk*.log $(SINE_LUT_HEX)