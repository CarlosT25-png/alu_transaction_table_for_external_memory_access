`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UTSA
// Engineer: Carlos Torres Valle
// 
// Create Date: 11/08/2025 01:06:50 PM
// Design Name: ALU with Transaction Table
// Module Name: Memory_Controller_tb
// Project Name: ALU with Transaction Table
// Target Devices: Nexys A7-100T
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Memory_Controller_tb();

    logic clk, reset_n;
    logic mem_read, mem_write;
    logic mem_wait;
    logic [31:0] mem_addr, i_mem_data, o_mem_addr, o_mem_data;

    Memory_Controller #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .MEMORY_SIZE(20),
        .READ_DELAY(5)
    ) Memory_Controller_instance (
        .clk(clk),
        .reset_n(reset_n),
        .i_mem_read(mem_read),
        .i_mem_write(mem_write),
        .i_mem_addr(mem_addr),
        .i_mem_data(i_mem_data),
        .o_mem_wait(mem_wait),
        .o_mem_addr(o_mem_addr),
        .o_mem_data(o_mem_data)
    );

    // setting clock for 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // resetting mem controller for a initial state
        reset_n = 0;
        mem_read = 0;
        mem_write = 0;
        mem_addr = 0;
        i_mem_data = 0;

        #20;
        // perform a write 
        reset_n = 1;
        mem_write = 1;
        mem_addr = 32'h0000_0004;
        i_mem_data = 32'h8044_fe12;

        @(posedge clk);

        mem_write = 0;

        @(posedge clk);
        // perform a read of the same location
        mem_read = 1;
        
        #15;
        
        mem_read = 0;

        #60;
        
        #20;

        $finish;


    end
    
    
endmodule
