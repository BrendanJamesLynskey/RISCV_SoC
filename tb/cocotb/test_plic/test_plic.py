# Brendan Lynskey 2025
# test_plic.py — CocoTB testbench for PLIC
# MIT License

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def reset_dut(dut):
    dut.srst.value = 1
    dut.irq_sources.value = 0
    dut.reg_wr_en.value = 0
    dut.reg_rd_en.value = 0
    dut.reg_addr.value = 0
    dut.reg_wdata.value = 0
    await ClockCycles(dut.clk, 5)
    dut.srst.value = 0
    await ClockCycles(dut.clk, 2)


async def reg_write(dut, addr, data):
    dut.reg_wr_en.value = 1
    dut.reg_addr.value = addr
    dut.reg_wdata.value = data
    await RisingEdge(dut.clk)
    dut.reg_wr_en.value = 0
    await RisingEdge(dut.clk)


async def reg_read(dut, addr):
    dut.reg_rd_en.value = 1
    dut.reg_addr.value = addr
    await RisingEdge(dut.clk)
    dut.reg_rd_en.value = 0
    await RisingEdge(dut.clk)
    return int(dut.reg_rdata.value)


@cocotb.test()
async def test_meip_init_low(dut):
    """meip should be low after reset with no sources."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    assert dut.meip.value == 0, "meip should be low after reset"


@cocotb.test()
async def test_source_not_enabled(dut):
    """Asserted but disabled source should not raise meip."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.irq_sources.value = 0x01
    await ClockCycles(dut.clk, 3)
    assert dut.meip.value == 0, "Disabled source should not raise meip"


@cocotb.test()
async def test_enabled_source_raises_meip(dut):
    """Enabled + asserted source should raise meip."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.irq_sources.value = 0x01
    await reg_write(dut, 0x004, 0x01)  # enable source 0
    await ClockCycles(dut.clk, 2)
    assert dut.meip.value == 1, "Enabled source should raise meip"


@cocotb.test()
async def test_threshold_blocks(dut):
    """Setting threshold above priority should suppress meip."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.irq_sources.value = 0x01
    await reg_write(dut, 0x004, 0x01)
    await reg_write(dut, 0x008, 0x07)  # threshold = 7 > priority 1
    await ClockCycles(dut.clk, 2)
    assert dut.meip.value == 0, "High threshold should suppress meip"


@cocotb.test()
async def test_deassert_clears_meip(dut):
    """Deasserting source should clear meip."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.irq_sources.value = 0x01
    await reg_write(dut, 0x004, 0x01)
    await ClockCycles(dut.clk, 2)
    assert dut.meip.value == 1

    dut.irq_sources.value = 0x00
    await ClockCycles(dut.clk, 2)
    assert dut.meip.value == 0, "meip should clear when source deasserts"


@cocotb.test()
async def test_priority_arbitration(dut):
    """Higher priority source should win claim."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Source 0: priority 1 (default), source 2: priority 5
    await reg_write(dut, 0x018, 0x05)  # source 2 priority
    await reg_write(dut, 0x004, 0x05)  # enable sources 0 and 2
    dut.irq_sources.value = 0x05       # assert sources 0 and 2
    await ClockCycles(dut.clk, 2)

    claim = await reg_read(dut, 0x00C)
    assert claim == 2, f"Expected source 2 (highest priority), got {claim}"
