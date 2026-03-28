`default_nettype none

module tt_um_emg_processor #(
    parameter THRESHOLD      = 4'd6,
    parameter DURATION_LIMIT = 4'd5
)(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Suppress unused input warnings
    wire _unused = &{ena, uio_in, ui_in[7:4], 1'b0};

    wire reset = ~rst_n;
    wire [3:0] emg_in = ui_in[3:0];

    reg valid_pulse;
    reg [3:0] event_counter;

    assign uo_out[0]   = valid_pulse;
    assign uo_out[4:1] = event_counter;
    assign uo_out[7:5] = 3'b000;

    // ----------------------------
    // 1. SHIFT REGISTER (flattened)
    // ----------------------------
    reg [3:0] sr0, sr1, sr2, sr3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sr0 <= 4'd0; sr1 <= 4'd0;
            sr2 <= 4'd0; sr3 <= 4'd0;
        end else begin
            sr0 <= emg_in;
            sr1 <= sr0;
            sr2 <= sr1;
            sr3 <= sr2;
        end
    end

    wire [5:0] sum      = sr0 + sr1 + sr2 + sr3;
    wire [3:0] filtered = sum[5:2];   // divide by 4 (right shift 2)

    // ----------------------------
    // 2. THRESHOLD DETECTION
    // ----------------------------
    wire above_threshold = (filtered > THRESHOLD);

    // ----------------------------
    // 3. TEMPORAL VALIDATION
    // ----------------------------
    reg [3:0] duration_counter;

    always @(posedge clk or posedge reset) begin
        if (reset)
            duration_counter <= 4'd0;
        else if (above_threshold)
            duration_counter <= duration_counter + 4'd1;
        else
            duration_counter <= 4'd0;
    end

    wire valid_event = (duration_counter >= DURATION_LIMIT);

    // ----------------------------
    // 4. EVENT COUNTER
    // ----------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            event_counter <= 4'd0;
        else if (valid_event)
            event_counter <= event_counter + 4'd1;
    end

    // ----------------------------
    // 5. FSM
    // ----------------------------
    reg [1:0] state;   // only 4 states needed — use 2 bits

    localparam IDLE     = 2'd0;
    localparam MONITOR  = 2'd1;
    localparam VALIDATE = 2'd2;
    localparam CONFIRM  = 2'd3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            valid_pulse <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid_pulse <= 1'b0;
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
                    valid_pulse <= 1'b1;
                    state       <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
