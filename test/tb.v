`timescale 1ns/1ps

module tb_emg_processor;

    // DUT signals
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg  ena;
    reg  clk;
    reg  rst_n;

    // Instantiate DUT
    tt_um_emg_processor #(
        .THRESHOLD(4'd6),
        .DURATION_LIMIT(4'd3)   // LOWER for fast simulation
    ) dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Task: apply EMG input
    task set_emg(input [3:0] val);
        begin
            ui_in[3:0] = val;
        end
    endtask

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        ena = 1;
        ui_in = 0;
        uio_in = 0;

        // Dump waves (for GTKWave)
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_emg_processor);

        // ----------------------------
        // RESET
        // ----------------------------
        #20;
        rst_n = 1;
        $display("Reset done");

        // ----------------------------
        // TEST 1: Noise (should NOT trigger)
        // ----------------------------
        $display("TEST 1: Noise");

        repeat (5) begin
            set_emg($random % 5);  // low random noise
            #10;
        end

        // ----------------------------
        // TEST 2: Short spike (should NOT trigger)
        // ----------------------------
        $display("TEST 2: Short spike");

        set_emg(4'd10); // above threshold
        #10;
        set_emg(4'd0);
        #20;

        // ----------------------------
        // TEST 3: Valid contraction (should trigger)
        // ----------------------------
        $display("TEST 3: Valid contraction");

        repeat (5) begin
            set_emg(4'd10);  // sustained high
            #10;
        end

        set_emg(4'd0);
        #20;

        // ----------------------------
        // TEST 4: Multiple contractions
        // ----------------------------
        $display("TEST 4: Repeated contractions");

        repeat (3) begin
            repeat (5) begin
                set_emg(4'd10);
                #10;
            end
            set_emg(0);
            #30;
        end

        // ----------------------------
        // END
        // ----------------------------
        $display("Simulation finished");
        #50;
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0t | EMG=%d | Pulse=%b | Count=%d",
                 $time,
                 ui_in[3:0],
                 uo_out[0],
                 uo_out[4:1]);
    end

endmodule
