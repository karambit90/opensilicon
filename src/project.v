`default_nettype none

module tt_um_emg_processor #(
    parameter THRESHOLD = 4'd6,
    parameter DURATION_LIMIT = 4'd5
)(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs (unused)
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      // always 1
    input  wire       clk,      
    input  wire       rst_n     
);

    // ----------------------------
    // Unused IOs
    // ----------------------------
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ----------------------------
    // Reset
    // ----------------------------
    wire reset = ~rst_n;

    // ----------------------------
    // Input mapping
    // ----------------------------
    wire [3:0] emg_in = ui_in[3:0];  // 4-bit EMG input

    // ----------------------------
    // Output mapping
    // ----------------------------
    reg valid_pulse;
    reg [3:0] event_counter;

    assign uo_out[0]   = valid_pulse;     // main output
    assign uo_out[4:1] = event_counter;   // debug: event count
    assign uo_out[7:5] = 3'b000;          // unused

    // ----------------------------
    // 1. SHIFT REGISTER (FILTER)
    // ----------------------------
    reg [3:0] shift_reg [0:3];

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1)
                shift_reg[i] <= 0;
        end else begin
            shift_reg[0] <= emg_in;
            shift_reg[1] <= shift_reg[0];
            shift_reg[2] <= shift_reg[1];
            shift_reg[3] <= shift_reg[2];
        end
    end

    wire [5:0] sum = shift_reg[0] + shift_reg[1] + shift_reg[2] + shift_reg[3];
    wire [3:0] filtered = sum >> 2;

    // ----------------------------
    // 2. THRESHOLD DETECTION
    // ----------------------------
    wire above_threshold = (filtered > THRESHOLD);

    // ----------------------------
    // 3. TEMPORAL VALIDATION
    // ----------------------------
    reg [3:0] duration_counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            duration_counter <= 0;
        end else if (above_threshold) begin
            duration_counter <= duration_counter + 1;
        end else begin
            duration_counter <= 0;
        end
    end

    wire valid_event = (duration_counter >= DURATION_LIMIT);

    // ----------------------------
    // 4. PATTERN COUNTER
    // ----------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            event_counter <= 0;
        end else if (valid_event) begin
            event_counter <= event_counter + 1;
        end
    end

    // ----------------------------
    // 5. FSM CONTROL
    // ----------------------------
    reg [2:0] state;

    localparam IDLE     = 3'd0;
    localparam MONITOR  = 3'd1;
    localparam VALIDATE = 3'd2;
    localparam CONFIRM  = 3'd3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid_pulse <= 0;
        end else begin
            case (state)

                IDLE: begin
                    valid_pulse <= 0;
                    if (above_threshold)
                        state <= MONITOR;
                end

                MONITOR: begin
                    if (above_threshold)
                        state <= VALIDATE;
                    else
                        state <= IDLE;
                end

                VALIDATE: begin
                    if (valid_event)
                        state <= CONFIRM;
                    else if (!above_threshold)
                        state <= IDLE;
                end

                CONFIRM: begin
                    valid_pulse <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
