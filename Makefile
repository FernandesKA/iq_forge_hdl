TOP        := phase_acc_tb
SNAPSHOT   := $(TOP)_sim

RTL_SRCS   := $(wildcard rtl/*.sv)
SIM_SRCS   := $(wildcard sim/*.sv)
ALL_SRCS   := $(RTL_SRCS) $(SIM_SRCS)

.PHONY: all sim sim_gui compile elaborate clean

all: sim

compile: $(ALL_SRCS)
	xvlog -sv $(ALL_SRCS)

elaborate: compile
	xelab $(TOP) -s $(SNAPSHOT)

sim: elaborate
	xsim $(SNAPSHOT) -runall

sim_gui: elaborate
	xsim $(SNAPSHOT) -gui

clean:
	rm -rf xsim.dir *.jou *.log *.pb *.wdb .Xil xelab.pb webtalk*.jou webtalk*.log