module lif_data_loader (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Serial data input
    input wire serial_data_in,
    input wire load_enable,
    
    // Outputs to LIF neuron
    output reg [2:0] weight_a,      // w_a parameter
    output reg [2:0] weight_b,      // w_b parameter  
    output reg [1:0] leak_config,   // leak configuration
    output reg [7:0] threshold_min, // minimum threshold
    output reg [7:0] threshold_max, // maximum threshold
    output reg params_ready         // Parameters loaded and ready
);

// State machine for parameter loading
parameter IDLE = 3'b000;
parameter LOAD_WA = 3'b001;
parameter LOAD_WB = 3'b010;
parameter LOAD_LEAK = 3'b011;
parameter LOAD_THR_MIN = 3'b100;
parameter LOAD_THR_MAX = 3'b101;
parameter READY = 3'b110;

// Internal registers
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [2:0] current_state;

// Edge detection for load_enable
reg load_enable_prev;
wire load_enable_rising;

// Default parameter values
parameter DEFAULT_WA = 3'd2;        // Default weight A
parameter DEFAULT_WB = 3'd2;        // Default weight B
parameter DEFAULT_LEAK = 2'd1;      // Default leak rate
parameter DEFAULT_THR_MIN = 8'd30;  // Default min threshold
parameter DEFAULT_THR_MAX = 8'd80;  // Default max threshold

assign load_enable_rising = load_enable & ~load_enable_prev;

always @(posedge clk) begin
    if (reset) begin
        load_enable_prev <= 1'b0;
    end else begin
        load_enable_prev <= load_enable;
    end
end

// State machine and serial loading logic
always @(posedge clk) begin
    if (reset) begin
        current_state <= IDLE;
        shift_reg <= 8'd0;
        bit_count <= 3'd0;
        weight_a <= DEFAULT_WA;
        weight_b <= DEFAULT_WB;
        leak_config <= DEFAULT_LEAK;
        threshold_min <= DEFAULT_THR_MIN;
        threshold_max <= DEFAULT_THR_MAX;
        params_ready <= 1'b1;  // Default params ready
    end else if (enable) begin
        case (current_state)
            IDLE: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_WA;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end
            end
            
            LOAD_WA: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        weight_a <= shift_reg[2:0]; // Use lower 3 bits
                        current_state <= LOAD_WB;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_WB: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        weight_b <= shift_reg[2:0]; // Use lower 3 bits
                        current_state <= LOAD_LEAK;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_LEAK: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        leak_config <= shift_reg[1:0]; // Use lower 2 bits
                        current_state <= LOAD_THR_MIN;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_THR_MIN: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        threshold_min <= shift_reg; // Full 8 bits
                        current_state <= LOAD_THR_MAX;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_THR_MAX: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        threshold_max <= shift_reg; // Full 8 bits
                        current_state <= READY;
                        params_ready <= 1'b1;
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_WA;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    current_state <= IDLE;
                end
            end
            
            default: begin
                current_state <= IDLE;
            end
        endcase
    end
end

endmodule
