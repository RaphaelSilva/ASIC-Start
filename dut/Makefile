# Cocotb Makefile

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(shell pwd)/../rtl/counter.v

TOPLEVEL = counter2b
MODULE = test_counter2b

include $(shell cocotb-config --makefiles)/Makefile.sim
