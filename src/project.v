/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_lif_neuron (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// Internal signals
wire reset;
wire enable;
wire load_mode;
wire serial_data;
wire [2:0] chan_a, chan_b;  // INCREASED PRECISION
wire spike_out;
wire [6:0] v_mem_out;
wire params_ready;

// Convert active-low reset to active-high
assign reset = ~rst_n;
assign enable = ena;

// Input mapping - UPDATED FOR 3-BIT CHANNELS (6 pins used, 2 reserved)
assign chan_a = ui_in[2:0];        // Channel A input (3 bits) - Higher precision!
assign chan_b = ui_in[5:3];        // Channel B input (3 bits) - Higher precision!
// ui_in[7:6] reserved for future expansion (2 pins remaining)

// Control inputs from bidirectional pins
assign load_mode = uio_in[0];      // Configuration mode
assign serial_data = uio_in[1];    // Serial parameter data

// Output mapping - 8 pins total
assign uo_out[6:0] = v_mem_out;    // Membrane potential (7 bits)
assign uo_out[7] = spike_out;      // Spike output (1 bit)

// Bidirectional IO configuration
assign uio_oe[7:0] = 8'b11111100;  // Bits [7:2] = output, [1:0] = input

// Bidirectional outputs
assign uio_out[0] = 1'b0;          // Input pin - don't drive
assign uio_out[1] = 1'b0;          // Input pin - don't drive
assign uio_out[2] = params_ready;  // Parameter loading status
assign uio_out[3] = spike_out;     // Duplicate spike for monitoring
assign uio_out[4] = |v_mem_out;    // Membrane activity indicator
assign uio_out[5] = load_mode;     // Echo load mode
assign uio_out[6] = serial_data;   // Echo serial data
assign uio_out[7] = enable;        // Echo enable status

// Instantiate LIF neuron system
lif_neuron_system lif_core (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .chan_a(chan_a),           // 3-bit channel A
    .chan_b(chan_b),           // 3-bit channel B
    .load_mode(load_mode),
    .serial_data(serial_data),
    .spike_out(spike_out),
    .v_mem_out(v_mem_out),
    .params_ready(params_ready)
);

// Handle unused inputs to prevent warnings
wire _unused = &{ui_in[7:6], uio_in[7:2], 1'b0};  // Updated for new pin usage

endmodule
