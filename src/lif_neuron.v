
module lif_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Input channels - INCREASED PRECISION
    input wire [2:0] chan_a,  // 3-bit precision (0-7)
    input wire [2:0] chan_b,  // 3-bit precision (0-7)
    
    // Configuration from loader
    input wire [2:0] weight_a,
    input wire [2:0] weight_b,
    input wire [1:0] leak_config,
    input wire [7:0] threshold_min,
    input wire [7:0] threshold_max,
    input wire params_ready,
    
    // Outputs
    output reg spike_out,
    output wire [6:0] v_mem_out  // 7-bit membrane potential output
);

// LIF parameters (adjusted for higher precision inputs)
parameter V_BITS = 8;
parameter THR_UP = 8'd4;   // Threshold increase after spike
parameter THR_DN = 8'd1;   // Threshold decrease when silent
parameter REFRAC_PERIOD = 4'd4; // Fixed refractory period

// State registers
reg [V_BITS-1:0] v_mem = 0;           // Membrane potential 0-255
reg [V_BITS-1:0] threshold;           // Adaptive threshold
reg [3:0] refr_cnt = 0;               // Refractory counter
reg [2:0] depress_a = 0;              // Short-term depression A
reg [2:0] depress_b = 0;              // Short-term depression B

// Decode leak rate from configuration
reg [2:0] leak_rate;
always @(*) begin
    case (leak_config)
        2'b00: leak_rate = 3'd1;
        2'b01: leak_rate = 3'd2;
        2'b10: leak_rate = 3'd3;
        default: leak_rate = 3'd4;
    endcase
end

// Effective weights with depression
wire [2:0] eff_weight_a = (weight_a > depress_a) ? (weight_a - depress_a) : 3'd0;
wire [2:0] eff_weight_b = (weight_b > depress_b) ? (weight_b - depress_b) : 3'd0;

// Input contributions - ADJUSTED FOR 3-BIT INPUTS
wire [5:0] contrib_a = chan_a * eff_weight_a;  // Max 7*7 = 49 < 64
wire [5:0] contrib_b = chan_b * eff_weight_b;  // Max 7*7 = 49 < 64
wire [6:0] weighted_sum = contrib_a + contrib_b; // Max 98 < 128

// Membrane potential output (map to 7 bits)
assign v_mem_out = v_mem[7:1]; // Upper 7 bits for output
reg [8:0] new_v; // 9-bit temporary for overflow prevention

// Main LIF dynamics
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 8'd0;
        threshold <= threshold_min;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
        depress_a <= 3'd0;
        depress_b <= 3'd0;
    end else if (enable && params_ready) begin
        // Refractory period handling
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            
            // Apply leak during refractory
            if (v_mem > leak_rate)
                v_mem <= v_mem - leak_rate;
            else
                v_mem <= 8'd0;
        end else begin
            // Normal operation: integrate and leak
            
            // Integration with leak - ADJUSTED FOR HIGHER INPUT PRECISION
            new_v = v_mem + weighted_sum - leak_rate;
            
            // Prevent underflow
            if (new_v[8]) // Negative (underflow)
                new_v = 9'd0;
            
            // Prevent overflow
            if (new_v > 255)
                new_v = 255;
            
            // Spike detection
            if (new_v >= threshold) begin
                spike_out <= 1'b1;
                v_mem <= 8'd0;  // Reset membrane potential
                refr_cnt <= REFRAC_PERIOD;
                
                // Adaptive threshold increase
                if (threshold + THR_UP <= threshold_max)
                    threshold <= threshold + THR_UP;
                else
                    threshold <= threshold_max;
                
                // Apply depression
                depress_a <= 3'd3;
                depress_b <= 3'd3;
            end else begin
                spike_out <= 1'b0;
                v_mem <= new_v[7:0];
                
                // Adaptive threshold decrease
                if (threshold > threshold_min + THR_DN)
                    threshold <= threshold - THR_DN;
                else
                    threshold <= threshold_min;
                
                // Depression recovery
                if (depress_a > 0) depress_a <= depress_a - 1;
                if (depress_b > 0) depress_b <= depress_b - 1;
            end
        end
    end else begin
        // Hold state when disabled or params not ready
        spike_out <= 1'b0;
    end
end

endmodule


