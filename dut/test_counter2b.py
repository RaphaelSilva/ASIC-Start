import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_counter_reset(dut):
    """Test directed reset."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Initial state
    dut.rst.value = 1
    dut.set.value = 0
    dut.cen.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert int(dut.cnt.value) == 0, f"Reset failed: expected 0, got {dut.cnt.value}"
    dut._log.info("Reset test passed")

@cocotb.test()
async def test_counter_set(dut):
    """Test set functionality."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst.value = 0
    dut.set.value = 1
    dut.cen.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert int(dut.cnt.value) == 3, f"Set failed: expected 3, got {dut.cnt.value}"
    dut._log.info("Set test passed")

@cocotb.test()
async def test_counter_increment(dut):
    """Test counter increment (cen is active low)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset first
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    dut.set.value = 0
    dut.cen.value = 0 # Enable counting (active low)
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.cnt.value) == 1, f"Increment failed: expected 1, got {dut.cnt.value}"
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.cnt.value) == 2, f"Increment failed: expected 2, got {dut.cnt.value}"
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.cnt.value) == 3, f"Increment failed: expected 3, got {dut.cnt.value}"
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.cnt.value) == 0, f"Overflow failed: expected 0, got {dut.cnt.value}"
    
    dut._log.info("Increment test passed")

@cocotb.test()
async def test_counter_hold(dut):
    """Test counter hold (cen is active low)."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Start from 1
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    dut.cen.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    # Hold
    dut.cen.value = 1
    current_val = int(dut.cnt.value)
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert int(dut.cnt.value) == current_val, f"Hold failed: expected {current_val}, got {dut.cnt.value}"
    dut._log.info("Hold test passed")
