SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(shell pwd)/../../../rtl/plic.sv
TOPLEVEL = plic
MODULE = test_plic
COMPILE_ARGS = -g2012
include $(shell cocotb-config --makefiles)/Makefile.sim
