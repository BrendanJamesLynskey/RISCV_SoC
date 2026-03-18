# Brendan Lynskey 2025
# test_axi_sram.py — CocoTB testbench for AXI SRAM slave
# MIT License

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def reset_dut(dut):
    dut.srst.value = 1
    dut.awvalid.value = 0
    dut.wvalid.value = 0
    dut.bready.value = 0
    dut.arvalid.value = 0
    dut.rready.value = 0
    await ClockCycles(dut.clk, 5)
    dut.srst.value = 0
    await ClockCycles(dut.clk, 2)


async def axi_write(dut, addr, data, strb=0xF):
    """Perform a single-beat AXI4 write."""
    dut.awvalid.value = 1
    dut.awaddr.value = addr
    dut.awid.value = 0
    dut.awlen.value = 0
    dut.awsize.value = 2
    dut.awburst.value = 1
    await RisingEdge(dut.clk)
    while dut.awready.value == 0:
        await RisingEdge(dut.clk)
    dut.awvalid.value = 0

    dut.wvalid.value = 1
    dut.wdata.value = data
    dut.wstrb.value = strb
    dut.wlast.value = 1
    await RisingEdge(dut.clk)
    while dut.wready.value == 0:
        await RisingEdge(dut.clk)
    dut.wvalid.value = 0
    dut.wlast.value = 0

    dut.bready.value = 1
    await RisingEdge(dut.clk)
    while dut.bvalid.value == 0:
        await RisingEdge(dut.clk)
    dut.bready.value = 0


async def axi_read(dut, addr):
    """Perform a single-beat AXI4 read, return data."""
    dut.arvalid.value = 1
    dut.araddr.value = addr
    dut.arid.value = 0
    dut.arlen.value = 0
    dut.arsize.value = 2
    dut.arburst.value = 1
    await RisingEdge(dut.clk)
    while dut.arready.value == 0:
        await RisingEdge(dut.clk)
    dut.arvalid.value = 0

    dut.rready.value = 1
    await RisingEdge(dut.clk)
    while dut.rvalid.value == 0:
        await RisingEdge(dut.clk)
    data = int(dut.rdata.value)
    dut.rready.value = 0
    return data


@cocotb.test()
async def test_write_read_word(dut):
    """Write a word and read it back."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    await axi_write(dut, 0x00, 0xDEADBEEF)
    rd = await axi_read(dut, 0x00)
    assert rd == 0xDEADBEEF, f"Expected 0xDEADBEEF, got 0x{rd:08X}"


@cocotb.test()
async def test_byte_lane_write(dut):
    """Write full word then overwrite one byte."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    await axi_write(dut, 0x04, 0xFFFFFFFF, strb=0xF)
    await axi_write(dut, 0x04, 0x000000AA, strb=0x1)
    rd = await axi_read(dut, 0x04)
    assert rd == 0xFFFFFFAA, f"Expected 0xFFFFFFAA, got 0x{rd:08X}"


@cocotb.test()
async def test_multiple_addresses(dut):
    """Write to multiple addresses, read all back."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    for i in range(4):
        await axi_write(dut, i * 4, (i + 1) * 0x11111111)
    for i in range(4):
        rd = await axi_read(dut, i * 4)
        exp = (i + 1) * 0x11111111
        assert rd == exp, f"Addr 0x{i*4:02X}: expected 0x{exp:08X}, got 0x{rd:08X}"


@cocotb.test()
async def test_uninit_reads_zero(dut):
    """Unwritten memory should read as zero."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    rd = await axi_read(dut, 0x100)
    assert rd == 0, f"Expected 0, got 0x{rd:08X}"


@cocotb.test()
async def test_read_resp_okay(dut):
    """Read response should be OKAY (0b00)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    dut.arvalid.value = 1
    dut.araddr.value = 0
    dut.arid.value = 0
    dut.arlen.value = 0
    dut.arsize.value = 2
    dut.arburst.value = 1
    await RisingEdge(dut.clk)
    while dut.arready.value == 0:
        await RisingEdge(dut.clk)
    dut.arvalid.value = 0
    dut.rready.value = 1
    await RisingEdge(dut.clk)
    while dut.rvalid.value == 0:
        await RisingEdge(dut.clk)
    assert int(dut.rresp.value) == 0, f"Expected OKAY, got {int(dut.rresp.value)}"
    dut.rready.value = 0


@cocotb.test()
async def test_write_resp_okay(dut):
    """Write response should be OKAY (0b00)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    await axi_write(dut, 0x00, 0x12345678)
    assert int(dut.bresp.value) == 0, f"Expected OKAY, got {int(dut.bresp.value)}"
