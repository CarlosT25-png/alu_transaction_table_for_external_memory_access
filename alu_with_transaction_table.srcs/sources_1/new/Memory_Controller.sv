`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UTSA
// Engineer: Carlos Torres Valle
// 
// Create Date: 11/07/2025 11:01:40 PM
// Design Name: ALU with Transaction Table
// Module Name: Memory_Controller
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


module Memory_Controller #(
    DATA_WIDTH = 32, // Bit width of our data
    ADDR_WIDTH = 32, // Bit width of our address
    MEMORY_SIZE = 20,   // size of our memory (e.g. 2**20)
    READ_DELAY = 100    // Delay (For simulation purpose) in clock cycles
) (
    input logic clk, reset_n, // clock and reset (active-low) signal
    input logic i_mem_read, i_mem_write, // bit signal for indicating if its a read or write
    input logic [ADDR_WIDTH-1:0] i_mem_addr, // input memory address
    input logic [DATA_WIDTH-1:0] i_mem_data, // input memory data
    output logic o_mem_wait, // to indicate if our memory is working on a write/reading
    output logic [ADDR_WIDTH-1: 0] o_mem_addr, // output memory address (For this project is needed to easily identify on the transaction table)
    output logic [DATA_WIDTH-1: 0] o_mem_data   // output memory return data
);

    typedef enum {
        IDLE,
        READ,
        WRITE
    } mem_states;

    mem_states current_state, next_state;

    // internal reg & wires
    logic [DATA_WIDTH-1: 0] memory [2**MEMORY_SIZE-1:0];
    logic [$clog2(READ_DELAY):0] delay_cnt;
    logic [$clog2(READ_DELAY):0] delay_cnt_next;
    
    logic [ADDR_WIDTH-1:0] internal_mem_addr; // for read & write
    logic [DATA_WIDTH-1:0] internal_mem_data; // only for writes
    logic already_written;


    always_ff @(posedge clk) begin
        if (~reset_n) begin
            for (int i = 0; i < 2**MEMORY_SIZE; i = i + 1) begin
                memory[i] = 0;
            end
            delay_cnt = 0;
            current_state <= IDLE; // TODO: Check for this
        end
        else begin
            current_state <= next_state;
            delay_cnt <= delay_cnt_next;
        end
    end

    always_comb begin
        // set the next states to current state
        next_state = current_state;
        delay_cnt_next = delay_cnt;

        // initialize variables
        o_mem_addr = 0;
        o_mem_data = 0;

        case (current_state)
            IDLE : begin
                if(i_mem_read == 1) begin
                    o_mem_wait = 0;
                    internal_mem_addr = i_mem_addr;
                    next_state = READ;
                end else if (i_mem_write) begin
                    o_mem_wait = 0;

                    internal_mem_addr = i_mem_addr;
                    internal_mem_data = i_mem_data;
                    next_state = WRITE;
                    already_written = 0;
                end else
                    o_mem_wait = 0;
            end
            READ : begin
                o_mem_wait = 1;
                if (delay_cnt < READ_DELAY) begin
                    delay_cnt_next = delay_cnt + 1;
                end else if (delay_cnt == READ_DELAY) begin
                    o_mem_wait = 0;
                    o_mem_addr = internal_mem_addr;
                    o_mem_data = memory[internal_mem_addr];
                    next_state = IDLE;
                    delay_cnt_next = 0;
                end
            end
            WRITE: begin
                o_mem_wait = 1;
                if(~already_written) begin
                    memory[internal_mem_addr] = internal_mem_data;
                    already_written = 1;
                    next_state = IDLE;
                end else
                    next_state = IDLE;

            end
            default: next_state = IDLE;
        endcase
        
    end
    
    
endmodule
