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
    parameter OP_CODE_WIDTH = 2 // width of op code
) (
    input logic clk, // system clok
    input logic reset_n, // reset active-low     

    // inputs from Control Logic Unit
    input logic i_request_load,
    input logic [ADDR_WIDTH-1:0] i_request_addr,
    input logic [DATA_WIDTH-1:0] i_request_data,
    input logic [OP_CODE_WIDTH-1:0] i_request_op_code, // we'll only support ADD & SUB for this project

    // input signals from memory
    input logic i_mem_done,
    input logic [DATA_WIDTH-1:0] i_mem_data,
    input logic [ADDR_WIDTH-1:0] i_mem_addr,


    // outputs for Control Logic
    output logic o_table_full,
    output logic o_request_accepted,
    output logic [DATA_WIDTH-1:0] o_request_result,
    output logic o_request_done,

    // outputs for the memory
    output logic o_mem_read,
    output logic o_mem_write,
    output logic [ADDR_WIDTH-1:0] o_mem_addr,
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
    logic [$clog2(TABLE_SIZE):0] entry_cnt_reg;
    logic [$clog2(TABLE_SIZE):0] entry_cnt_next;
    logic found_record;
    logic found_record_idx;
    logic found_free_spot;
    logic free_spot_idx;

    always_ff @(posedge clk) begin
        if(~reset_n) begin
            for (int i = 0; i < TABLE_SIZE ; i = i + 1) begin
                transaction_table_reg[i] <= 0;
            end
            
            entry_cnt_reg <= 0;
        end else begin
            transaction_table_reg <= transaction_table_next;
            entry_cnt_reg <= entry_cnt_next;
        end
    end

    always_comb begin
        transaction_table_next = transaction_table_reg;
        entry_cnt_next = entry_cnt_reg;

        // set initial value
        o_table_full         = 1'b0;
        o_request_accepted   = 1'b0;
        o_request_result     = 1'b0;
        o_request_done       = 1'b0;

        o_mem_read           = 1'b0;
        o_mem_write          = 1'b0;
        o_mem_addr           = 1'b0;
        o_mem_data     = 1'b0;

        // found variables
        found_record = 1'b0;
        found_free_spot = 1'b0;
        found_record_idx = 0;
        free_spot_idx = 0;

        for (int i = 0; i < TABLE_SIZE; i = i + 1) begin
            if (transaction_table_reg[i].address == i_request_addr
            && transaction_table_reg[i].in_progress == 1'b1
            && transaction_table_reg[i].deprecated == 1'b0) begin

                found_record = 1;
                found_record_idx = i;

            end

            if(transaction_table_reg[i].in_progress == 1'b0 && found_free_spot == 0) begin
                found_free_spot = 1;
                free_spot_idx = i;
            end
        end


        // check table size
        if (entry_cnt_reg == TABLE_SIZE) begin
            o_table_full = 1;
        end

        
        if (i_mem_done) begin
            // loop through table and find the matching record
            found_record = 0;
            found_record_idx = 0;
            for (int i = 0; i < TABLE_SIZE; i = i + 1) begin
                if (transaction_table_reg[i].address == i_mem_addr // <<< Check against i_mem_addr
                && transaction_table_reg[i].in_progress == 1'b1
                && transaction_table_reg[i].deprecated == 1'b0) begin
                    found_record = 1;
                    found_record_idx = i;
                end
            end

            if (found_record) begin
                // write into memory
                o_mem_addr = transaction_table_reg[found_record_idx].address;
                o_mem_data = signed'(i_mem_data) + signed'(transaction_table_reg[found_record_idx].accumulator);
                o_mem_write = 1;

                // output result
                o_request_done = 1;
                $display("Values for i_mem_data and transaction table reg accumulator");
                $display(o_mem_addr);
                $display(i_mem_data);
                $display(transaction_table_reg[found_record_idx].accumulator);
                
                o_request_result = signed'(i_mem_data) + signed'(transaction_table_reg[found_record_idx].accumulator);

                // update record in the transaction table
                transaction_table_next[found_record_idx].in_progress = 1'b0; 
                transaction_table_next[found_record_idx].deprecated = 1'b1;
                transaction_table_next[found_record_idx].mem_value = i_mem_data; 
                
                entry_cnt_next = entry_cnt_reg - 1;
            end
        end
        else if(i_request_load == 1) begin
            if (found_record) begin
                // Update the record
                transaction_table_next[found_record_idx].op_count = transaction_table_reg[found_record_idx].op_count + 1;

                if (i_request_op_code == 1) begin // SUB
                    transaction_table_next[found_record_idx].accumulator = 
                        signed'(transaction_table_reg[found_record_idx].accumulator) - signed'(i_request_data);
                end else // ADD
                    transaction_table_next[found_record_idx].accumulator = 
                        signed'(transaction_table_reg[found_record_idx].accumulator) + signed'(i_request_data);

                o_request_accepted = 1;
            end
            else if (!o_table_full) begin
                // Create a new record in the table
                transaction_table_next[free_spot_idx].in_progress   = 1'b1;
                transaction_table_next[free_spot_idx].deprecated    = 1'b0;
                transaction_table_next[free_spot_idx].address       = i_request_addr;
                transaction_table_next[free_spot_idx].op_count      = 1;
                transaction_table_next[free_spot_idx].accumulator   = i_request_data;
                transaction_table_next[free_spot_idx].mem_value     = 0;
                transaction_table_next[free_spot_idx].mem_read_sent = 1'b1; // We will send a read

                if (i_request_op_code == 1) begin // SUB
                    transaction_table_next[free_spot_idx].accumulator = -signed'(i_request_data); // unary minus
                end else // ADD
                    transaction_table_next[free_spot_idx].accumulator = i_request_data;

                entry_cnt_next = entry_cnt_reg + 1;
                o_mem_read = 1;
                o_mem_addr = i_request_addr;
                o_request_accepted = 1;
            end
            else begin
                o_request_accepted = 0;
            end
        end


    end
endmodule
