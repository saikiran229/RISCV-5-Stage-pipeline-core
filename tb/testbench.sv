`timescale 1ns / 1ps

module tb_RISCV_Core;

    logic clk;
    logic rst;

    // Instantiate the pipeline
    RISCV_Core uut (
        .clk(clk),
        .rst(rst)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Standard waveform dumping
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_RISCV_Core);

        // Initialize signals
        clk = 0;
        rst = 1;

        #20;
        rst = 0;

        // Run long enough to let your program.mem finish
        #300;

        $display("Simulation complete.");
        $finish;
    end
endmodule
