`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2025 09:54:31 PM
// Design Name: 
// Module Name: Standard_ALU
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


module Standard_ALU #(
    parameter ADDR_WIDTH = 32, // width of memory address
    parameter DATA_WIDTH = 32, // width of memory data
    parameter OP_CODE_WIDTH = 2 // width of op code
) (
    input logic clk, reset_n,

    // ALU control signals
    input logic [ADDR_WIDTH-1:0] i_request_addr,
    input logic [DATA_WIDTH-1:0] i_request_data,
    input logic i_request_load,
    input logic [OP_CODE_WIDTH-1:0] i_request_op_code, // 0 for ADD; 1 for SUB

    // input signals from memory (Return Values)
    input logic i_mem_done,
    input logic [DATA_WIDTH-1:0] i_mem_data,
    input logic [ADDR_WIDTH-1:0] i_mem_addr,

    // outputs for Control Logic
    output logic o_alu_ready, // 1 if ALU is ready for a new operation
    output logic [DATA_WIDTH-1:0] o_request_result,
    output logic o_request_done,

    // outputs for the memory (ALU -> Memory Controller)
    output logic o_mem_read,
    output logic o_mem_write,
    output logic [ADDR_WIDTH-1:0] o_mem_addr,
    output logic [DATA_WIDTH-1:0] o_mem_data
);

    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;

    typedef enum {
        IDLE,
        READ_WAIT,
        WRITE_MEM,  // <<< FIX: Renamed
        WRITE_WAIT  // <<< FIX: Added state to prevent race condition
    } alu_states;

    alu_states current_state, next_state;

    logic [ADDR_WIDTH-1:0] internal_addr_reg, internal_addr_next;
    logic [DATA_WIDTH-1:0] internal_data_reg, internal_data_next;
    logic [OP_CODE_WIDTH-1:0] internal_op_code_reg, internal_op_code_next;
    
    logic [DATA_WIDTH-1:0] internal_write_data_reg, internal_write_data_next;


    always_ff @(posedge clk or negedge reset_n) begin // <<< FIX: Added async reset
        if(~reset_n) begin
            current_state <= IDLE;
            internal_addr_reg <= '0;
            internal_data_reg <= '0;
            internal_op_code_reg <= '0;
            internal_write_data_reg <= '0;
        end else begin
            current_state <= next_state;
            internal_addr_reg <= internal_addr_next;
            internal_data_reg <= internal_data_next;
            internal_op_code_reg <= internal_op_code_next;
            internal_write_data_reg <= internal_write_data_next;
        end
    end

    always_comb begin
        // Initial state to avoid latches
        next_state = current_state;
        
        internal_addr_next = internal_addr_reg;
        internal_data_next = internal_data_reg;
        internal_op_code_next = internal_op_code_reg;
        internal_write_data_next = internal_write_data_reg;

        o_alu_ready = 0;
        o_request_result = 0;
        o_request_done = 0;

        o_mem_read = 0;
        o_mem_write = 0;
        o_mem_data = 0;
        o_mem_addr = 0;

        case (current_state)
            IDLE : begin
                o_alu_ready = 1;
                if(i_request_load) begin
                    // <<< FIX: Assign to _next variables
                    internal_addr_next = i_request_addr;
                    internal_data_next = i_request_data;
                    internal_op_code_next = i_request_op_code;
                    
                    o_mem_addr = i_request_addr; // Combinational read
                    o_mem_read = 1;
                    next_state = READ_WAIT;
                end
            end
            
            READ_WAIT : begin
                // We are stalled (o_alu_ready is 0)
                if (~i_mem_done) begin
                    // Keep asserting read until done
                    o_mem_addr = internal_addr_reg;
                    o_mem_read = 1;
                end else begin
                    // Memory is done, calculate result
                    o_mem_read = 0;
                    
                    if (internal_op_code_reg == OP_SUB) begin
                        internal_write_data_next = signed'(i_mem_data) - signed'(internal_data_reg);
                    end else begin
                        internal_write_data_next = signed'(i_mem_data) + signed'(internal_data_reg);
                    end
                    
                    next_state = WRITE_MEM;
                end
            end
            
            WRITE_MEM: begin
                // We are stalled
                o_mem_addr = internal_addr_reg;
                o_mem_data = internal_write_data_reg; // <<< FIX: Use registered result
                o_mem_write = 1;
                
                next_state = WRITE_WAIT;
            end

            WRITE_WAIT: begin
                // We are still stalled, but now we can send the result
                // and go back to IDLE.
                o_request_done = 1;
                o_request_result = internal_write_data_reg;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase

    end


endmodule