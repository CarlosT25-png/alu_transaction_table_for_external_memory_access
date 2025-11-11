`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2025 11:04:19 PM
// Design Name: 
// Module Name: Transaction_Table_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Transaction_Table_tb();

    logic clk, reset_n;
    logic i_request_load, o_request_accepted, o_request_done, o_table_full;
    logic [31:0] i_request_addr, i_request_data, o_request_result;
    logic [1:0] i_request_op_code;


    logic i_mem_read, i_mem_write, o_mem_done;
    logic [31:0] i_mem_addr, i_mem_data, o_mem_addr, o_mem_data;

    Memory_Controller #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .MEMORY_SIZE(20),
        .READ_DELAY(5)
    ) Memory_Controller_instance (
        .clk(clk),
        .reset_n(reset_n),
        .i_mem_read(i_mem_read),
        .i_mem_write(i_mem_write),
        .i_mem_addr(i_mem_addr),
        .i_mem_data(i_mem_data),
        .o_mem_done(o_mem_done),
        .o_mem_addr(o_mem_addr),
        .o_mem_data(o_mem_data)
    );

    Transaction_Table #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .TABLE_SIZE(4),
        .OP_CODE_WIDTH(2)
    ) Transaction_Table_instance (
        .clk(clk),
        .reset_n(reset_n),
        .i_request_load(i_request_load),
        .i_request_addr(i_request_addr),
        .i_request_data(i_request_data),
        .i_request_op_code(i_request_op_code),
        .i_mem_done(o_mem_done),
        .i_mem_data(o_mem_data),
        .i_mem_addr(o_mem_addr),
        .o_table_full(o_table_full),
        .o_request_accepted(o_request_accepted),
        .o_request_result(o_request_result),
        .o_request_done(o_request_done),
        .o_mem_read(i_mem_read),
        .o_mem_write(i_mem_write),
        .o_mem_addr(i_mem_addr),
        .o_mem_data(i_mem_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_request(
        input [31:0] addr,
        input [31:0] data,
        input [1:0]  op
    );
        @(posedge clk);
        i_request_load    <= 1'b1;
        i_request_addr    <= addr;
        i_request_data    <= data;
        i_request_op_code <= op;
        
        wait (o_request_accepted == 1'b1 || o_table_full == 1'b1);
        
        @(posedge clk);
        i_request_load <= 1'b0;
    endtask

    initial begin
        reset_n = 0;

        i_request_load = 0;
        i_request_addr = 0;
        i_request_data = 0;
        i_request_op_code = 0;

        #20;

        reset_n = 1;

        #20;

        // Test 1: Aggregation on Addr 4 - It should only do one read and one write
        send_request(32'h0000_0004, 32'h0000_0002, 0); // accum = 2
        send_request(32'h0000_0004, 32'h0000_0007, 0); // accum = 2 + 7 = 9
        send_request(32'h0000_0004, 32'h0000_0004, 1); // accum = 2 + 7 - 4 = 5
        
        // Test 2: Aggregation on Addr 10 (A)
        send_request(32'h0000_0008, 32'h0000_000A, 0); // accum = 10
        send_request(32'h0000_0008, 32'h0000_0007, 1); // accum = 10 -7 = 3

        #100; 
        // Test 1 (Continuation): it should create another read and write
        send_request(32'h0000_0004, 32'h0000_0009, 0); // accum = 5 + 9 = E

        #100;
        send_request(32'h0000_0008, 32'h0000_0005, 0); // accum = 3 + 5 = 8

        #100;
        $finish;

    end


endmodule
