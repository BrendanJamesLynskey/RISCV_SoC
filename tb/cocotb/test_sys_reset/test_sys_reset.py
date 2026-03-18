# Brendan Lynskey 2025
# test_sys_reset.py — CocoTB testbench for reset controller
# MIT License

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


@cocotb.test()
async def test_reset_asserted(dut):
    """srst should be high while ext_rst_n is low."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.ext_rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    assert dut.srst.value == 1, "srst should be high during reset"


@cocotb.test()
async def test_reset_deasserted(dut):
    """srst should go low after ext_rst_n rises and sync stages drain."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.ext_rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.ext_rst_n.value = 1
    await ClockCycles(dut.clk, 6)
    assert dut.srst.value == 0, "srst should be low after sync stages"


@cocotb.test()
async def test_glitch_rejection(dut):
    """Brief ext_rst_n assertion should still propagate through pipeline."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.ext_rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    assert dut.srst.value == 0

    # Brief reset pulse
    dut.ext_rst_n.value = 0
    await ClockCycles(dut.clk, 1)
    dut.ext_rst_n.value = 1
    await ClockCycles(dut.clk, 1)
    # Should have propagated into pipe
    assert dut.srst.value == 1, "Reset should propagate into pipe"
    await ClockCycles(dut.clk, 6)
    assert dut.srst.value == 0, "Should recover after sync stages"
