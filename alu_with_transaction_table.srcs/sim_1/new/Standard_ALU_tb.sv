`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2025 10:40:04 PM
// Design Name: 
// Module Name: Standard_ALU_tb
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


module Standard_ALU_tb();

    logic clk, reset_n, o_alu_ready;
    logic i_request_load, o_request_done;
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


    Standard_ALU #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .OP_CODE_WIDTH(2)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .i_request_addr(i_request_addr),
        .i_request_data(i_request_data),
        .i_request_load(i_request_load),
        .i_request_op_code(i_request_op_code),
        .i_mem_done(o_mem_done),
        .i_mem_data(o_mem_data),
        .i_mem_addr(o_mem_addr),
        .o_alu_ready(o_alu_ready),
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

    // ready (o_alu_ready) and then wait for it to be done (o_request_done).
    task send_request(
        input [31:0] addr,
        input [31:0] data,
        input [1:0]  op
    );
        // Step 1: Wait for the ALU to be in the IDLE state (ready)
        wait (o_alu_ready == 1'b1);
        
        // Step 2: Send the request for one clock cycle
        @(posedge clk);
        i_request_load    <= 1'b1;
        i_request_addr    <= addr;
        i_request_data    <= data;
        i_request_op_code <= op;
        
        // Wait for the ALU to accept the request (it will no longer be ready)
        wait (o_alu_ready == 1'b0);
        
        @(posedge clk);
        i_request_load <= 1'b0;
        
        // Step 3: Wait for the *entire* operation (Read-Modify-Write)
        // to complete. The ALU signals this by pulsing o_request_done.
        wait (o_request_done == 1'b1);
        
        $display("@%t: Standard_ALU: Finished request for addr %h. Result: %h",
                 $time, addr, o_request_result);
                 
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

        // Test 1: Aggregation on Addr 4
        // The 'send_request' task will now stall
        // until each operation is fully complete.
        $display("@%t: TB: Sending req 1 (Addr 4, +2)", $time);
        send_request(32'h0000_0004, 32'h0000_0002, 0); 
        
        $display("@%t: TB: Sending req 2 (Addr 4, +7)", $time);
        send_request(32'h0000_0004, 32'h0000_0007, 0); 
        
        $display("@%t: TB: Sending req 3 (Addr 4, -4)", $time); // Expected result 5
        send_request(32'h0000_0004, 32'h0000_0004, 1); 
        
        // Test 2: Aggregation on Addr 10 (A)
        $display("@%t: TB: Sending req 4 (Addr 8, +10)", $time);
        send_request(32'h0000_0008, 32'h0000_000A, 0); 
        
        $display("@%t: TB: Sending req 5 (Addr 8, -7)", $time); // Expected result 3
        send_request(32'h0000_0008, 32'h0000_0007, 1); 

        // Test 1 (continuation)
        $display("@%t: TB: Sending req 6 (Addr 4, +9)", $time); // Mem = 5 + 9 = 0xe
        send_request(32'h0000_0004, 32'h0000_0009, 0); 

        // Test 2 (continuation)
        $display("@%t: TB: Sending req 7 (Addr 8, +5)", $time); // Expected result: 0x14
        send_request(32'h0000_0008, 32'h0000_0005, 0); 

        #100;
        $display("@%t: TB: Test finished.", $time);
        $finish;

    end

endmodule