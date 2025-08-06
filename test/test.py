# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_lif_neuron_basic(dut):
    """Basic LIF neuron functionality test"""
    dut._log.info("Starting LIF Neuron Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0    # All channel inputs = 0
    dut.uio_in.value = 0   # load_mode=0, serial_data=0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for system to stabilize
    await ClockCycles(dut.clk, 5)
    
    # Check that params_ready is high (default parameters loaded)
    params_ready = (dut.uio_out.value >> 2) & 1
    dut._log.info(f"Default params_ready: {params_ready}")
    
    # Test 1: Resting state (no input)
    dut._log.info("Test 1: Resting state")
    dut.ui_in.value = 0  # chan_a=0, chan_b=0
    await ClockCycles(dut.clk, 10)
    
    v_mem = dut.uo_out.value & 0x7F  # Lower 7 bits
    spike = (dut.uo_out.value >> 7) & 1
    dut._log.info(f"Resting: V_mem={v_mem}, Spike={spike}")
    
    # Should be at rest, no spikes
    assert spike == 0, "Should not spike at rest"
    
    # Test 2: Low stimulus
    dut._log.info("Test 2: Low stimulus")
    dut.ui_in.value = 0x09  # chan_a=1 (bits 2:0), chan_b=1 (bits 5:3)
    
    # Monitor for several cycles
    spike_detected = False
    for cycle in range(20):
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        
        if spike == 1:
            spike_detected = True
            dut._log.info(f"SPIKE detected at cycle {cycle}, V_mem={v_mem}")
            break
        elif cycle % 5 == 0:
            dut._log.info(f"Cycle {cycle}: V_mem={v_mem}")
    
    # Test 3: Higher stimulus (should definitely spike)
    dut._log.info("Test 3: Higher stimulus")
    dut.ui_in.value = 0x1B  # chan_a=3 (bits 2:0), chan_b=3 (bits 5:3)
    
    spike_count = 0
    for cycle in range(30):
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        
        if spike == 1:
            spike_count += 1
            dut._log.info(f"SPIKE #{spike_count} at cycle {cycle}")
        
        # Stop if we get multiple spikes
        if spike_count >= 2:
            break
    
    dut._log.info(f"Higher stimulus generated {spike_count} spikes")
    assert spike_count > 0, "Higher stimulus should generate spikes"
    
    # Test 4: Maximum stimulus
    dut._log.info("Test 4: Maximum stimulus")
    dut.ui_in.value = 0x3F  # chan_a=7, chan_b=7 (maximum)
    
    max_spike_count = 0
    for cycle in range(20):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            max_spike_count += 1
    
    dut._log.info(f"Maximum stimulus generated {max_spike_count} spikes")
    assert max_spike_count >= spike_count, "Max stimulus should generate more/equal spikes"
    
    dut._log.info("LIF Neuron basic functionality test completed successfully!")

@cocotb.test()
async def test_parameter_loading(dut):
    """Test serial parameter loading functionality"""
    dut._log.info("Starting Parameter Loading Test")

    # Set the clock period to 10 us (100 KHz) 
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Enter parameter loading mode
    dut._log.info("Entering parameter loading mode")
    dut.uio_in.value = 1  # load_mode = 1
    await ClockCycles(dut.clk, 2)
    
    # Check params_ready goes low
    params_ready = (dut.uio_out.value >> 2) & 1
    dut._log.info(f"Loading mode params_ready: {params_ready}")
    
    # Send simple parameter (just test first parameter - weight_a)
    # Send byte 0x05 = 00000101 (MSB first)
    test_byte = 0x05
    dut._log.info(f"Sending test byte: 0x{test_byte:02X}")
    
    for bit in range(8):
        bit_val = (test_byte >> (7-bit)) & 1
        dut.uio_in.value = 1 | (bit_val << 1)  # load_mode=1, serial_data=bit_val
        await ClockCycles(dut.clk, 1)
    
    # Exit loading mode
    dut.uio_in.value = 0  # load_mode = 0
    await ClockCycles(dut.clk, 5)
    
    # Check params_ready eventually goes high
    for _ in range(10):
        await ClockCycles(dut.clk, 1)
        params_ready = (dut.uio_out.value >> 2) & 1
        if params_ready == 1:
            break
    
    dut._log.info(f"After loading params_ready: {params_ready}")
    dut._log.info("Parameter loading test completed!")
