SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(shell pwd)/../../../rtl/sys_reset.sv
TOPLEVEL = sys_reset
MODULE = test_sys_reset
COMPILE_ARGS = -g2012
include $(shell cocotb-config --makefiles)/Makefile.sim
