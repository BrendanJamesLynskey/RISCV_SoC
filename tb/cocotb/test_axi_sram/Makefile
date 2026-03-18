SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(shell pwd)/../../../rtl/axi_sram.sv
TOPLEVEL = axi_sram
MODULE = test_axi_sram
COMPILE_ARGS = -g2012
include $(shell cocotb-config --makefiles)/Makefile.sim
