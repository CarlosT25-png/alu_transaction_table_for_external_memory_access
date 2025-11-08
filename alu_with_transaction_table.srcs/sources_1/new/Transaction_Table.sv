`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UTSA
// Engineer: Carlos Torres Valle
// 
// Create Date: 11/05/2025 09:52:35 PM
// Design Name: ALU with Transaction Table
// Module Name: Transaction_Table
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

// Based on the DLX CPU instructions & Datapath

module Transaction_Table #(
    parameter ADDR_WIDTH = 32, // width of memory address
    parameter DATA_WIDTH = 32, // width of memory data
    parameter TABLE_SIZE = 4, // size of the transaction table (How many rows)
    parameter OP_CODE_WIDTH = 5 // width of memory address
) (
    input logic clk, // system clok
    input logic reset_n, // reset active-low     

    // inputs from Control Logic Unit
    input logic request_load,
    input logic [ADDR_WIDTH-1:0] request_addr,
    input logic [DATA_WIDTH-1:0] request_data,
    input logic [OP_CODE_WIDTH-1:0] request_op_code,

    // input signals from memory
    input logic mem_done,
    input logic mem_wait,
    input logic [DATA_WIDTH-1:0] mem_data,


    // outputs for Control Logic
    output logic table_full,
    output logic request_accepted,
    output logic [DATA_WIDTH-1:0] request_result,
    output logic request_done,

    // outputs for the memory
    output logic mem_read,
    output logic mem_write,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] o_mem_data
    // to simplify my module, it only support word size (or the size specificied in the parameter)
);

    typedef struct packed {
        logic in_progress; // if the entry is being use
        logic deprecated; // the entry already finished
        logic [ADDR_WIDTH-1:0] address; // mem address
        logic [2:0] op_count; // how many operations are pending
        logic [DATA_WIDTH-1:0] accumulator; // The aggregated operations
        logic [DATA_WIDTH-1:0] mem_value; // returned value from mem
        logic mem_read_sent;
    } TableEntry;

    TableEntry [TABLE_SIZE-1:0] transaction_table_reg;
    TableEntry [TABLE_SIZE-1:0] transaction_table_next; // future state for our reg

    // internal signal for combination circuit
    integer i;
    logic [$clog2(TABLE_SIZE):0] entry_cnt_reg;
    logic [$clog2(TABLE_SIZE):0] entry_cnt_next;
    logic found_record;
    logic found_record_idx;
    logic found_free_spot;
    logic free_spot_idx;

    always_ff @(posedge clk) begin
    end

    always_comb begin
        transaction_table_next = transaction_table_reg;
        entry_cnt_next = entry_cnt_reg;

        // set initial value
        table_full         = 1'b0;
        request_accepted   = 1'b0;
        request_result     = 1'b0;
        request_done       = 1'b0;

        mem_read           = 1'b0;
        mem_write          = 1'b0;
        mem_addr           = 1'b0;
        o_mem_data     = 1'b0;

        // found variables
        found_record = 1'b0;
        found_free_spot = 1'b0;
        found_record_idx = 0;
        free_spot_idx = 0;

        for ( i = 0; i < TABLE_SIZE; i = i + 1) begin
            if (transaction_table_reg[i].address == request_addr
            && transaction_table_reg[i].in_progress == 1'b1
            && transaction_table_reg[i].deprecated == 1'b0) begin
                
                found_record = 1;
                found_record_idx = i;

            end

            if(transaction_table_reg[i].deprecated == 0 && found_free_spot == 0) begin
                found_free_spot = 1;
                free_spot_idx = i;
            end
        end


        // check table size
        if (entry_cnt_reg == TABLE_SIZE) begin
            table_full = 1;
        end
        

        // check incoming requests
        if(request_load == 1) begin
            if (found_record) begin
                // TODO: add to accumulator
                // transaction table update accumulator 
                request_accepted = 1;
            end
            else if (!table_full) begin
                transaction_table_next[free_spot_idx].in_progress   = 1'b1;
                transaction_table_next[free_spot_idx].deprecated    = 1'b0;
                transaction_table_next[free_spot_idx].address       = request_addr;
                transaction_table_next[free_spot_idx].op_count      = 1;
                transaction_table_next[free_spot_idx].accumulator   = request_data; // Assuming ADD
                transaction_table_next[free_spot_idx].mem_value     = '0;
                transaction_table_next[free_spot_idx].mem_read_sent = 1'b1; // We will send a read

                entry_cnt_next = entry_cnt_reg + 1;
                mem_read = 1;
                mem_addr = request_addr;
                request_accepted = 1;
            end
            else begin
                request_accepted = 0;
            end
        end

        // TODO: MemDone
    end
endmodule
