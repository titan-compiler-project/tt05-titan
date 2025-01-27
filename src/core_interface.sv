// example only
// this will work for a function that has 2 inputs and 1 output, which are 32 bits wide
// this must be generated by titan for each function
// import TitanComms::*;
// `include "instruction_params.vh"

module core_interface # (
    parameter INSTRUCTION_WIDTH = 8,
    parameter ADDRESS_WIDTH = 24,
    parameter VALUE_WIDTH = 32,
    parameter TOTAL_INPUTS,
    parameter TOTAL_OUTPUTS,
    parameter START_ADDRESS,
    parameter END_ADDRESS
) (
    input wire clk_i,
    input wire [INSTRUCTION_WIDTH-1:0] instruction_i,
    input wire [ADDRESS_WIDTH-1:0] address_i,
    input wire [VALUE_WIDTH-1:0] value_i,
    output wire [VALUE_WIDTH-1:0] result_o,
    output reg [VALUE_WIDTH-1:0] stream_o,
    output wire core_interrupt_wo
);

    parameter WRITE = 1;
    parameter READ = 2;
    parameter STREAM = 3;
    parameter BIND_INTERRUPT = 4;
    parameter BIND_READ_ADDRESS = 5;
    parameter BIND_WRITE_ADDRESS = 6;
    parameter TRANSFER = 7;
    parameter REPEAT = 8;

    localparam LAST_INPUT_ADDRESS = END_ADDRESS - TOTAL_OUTPUTS;

    // need address in normal range to index memory, not global range
    wire [ADDRESS_WIDTH-1:0] normalised_input_address = address_i - START_ADDRESS;
    wire [ADDRESS_WIDTH-1:0] normalised_ouput_address = address_i - LAST_INPUT_ADDRESS;

    
    // if we're getting talked to, and which parts specifically
    wire interface_enable = ((address_i >= START_ADDRESS) & (address_i <= END_ADDRESS));
    wire addressing_inputs = (address_i >= START_ADDRESS) & (address_i <= LAST_INPUT_ADDRESS);
    wire addressing_outputs = (address_i > LAST_INPUT_ADDRESS) & (address_i <= END_ADDRESS);
    
    
    logic [VALUE_WIDTH-1:0] input_memory [0:1];  // use params to calculate required depth
    logic [VALUE_WIDTH-1:0] output_memory; // if only one output, we can't make instance using [0]

    (*keep = 1*) logic interrupt_enabled = 0;
    // logic core_done_signal;

    assign core_interrupt_wo = interrupt_enabled;
    
    logic stream_enabled = 0;
    // logic stream_i_or_o = 0; // 0 = inputs, 1 = outputs
    logic [ADDRESS_WIDTH-1:0] normalised_stream_read_address;
    logic [ADDRESS_WIDTH-1:0] normalised_stream_write_address;
	 
    reg [VALUE_WIDTH-1:0] output_val_internal;

    add_2 uut_add2 (
        .clock(clk_i), .a(input_memory[0]), .b(input_memory[1]), .c(output_memory)
    );    

	 always @ (posedge clk_i) begin
        // if not being addressed but the current instruction is BINDx then we need to disable our stream output 
        if (!interface_enable & ((instruction_i == BIND_READ_ADDRESS) | (instruction_i == BIND_WRITE_ADDRESS))) begin
            stream_enabled <= 0;
            // stream_bus <= 'hz;
        end

        // TODO: if (stream_enabled) here instead?
        if (instruction_i == STREAM) begin
            if (stream_enabled) begin
                input_memory[normalised_stream_write_address] <= value_i;

                // need to replace with index if multiple outputs
                stream_o <= output_memory;
            end
        end else if (interface_enable) begin
        // if (interface_enable) begin
           unique case (instruction_i)

                READ: begin
                    if (addressing_inputs) begin
                        output_val_internal <= input_memory[normalised_input_address];
                    end else if (addressing_outputs) begin
                        // only usable with multiple outputs
                        // output_val_internal <= output_memory[normalised_ouput_address];
                        output_val_internal <= output_memory;
                    end
                end

                WRITE: begin
                    // writing to output_memory is illegal because it would lead to multiple drivers
                    if (addressing_inputs) begin
                        input_memory[normalised_input_address] <= value_i;
                    end
                end

                BIND_INTERRUPT: begin
                    interrupt_enabled <= 1;    
                    input_memory[0] <= input_memory[0] + 1;
                end

                BIND_READ_ADDRESS: begin
                    if (addressing_outputs) begin
                        stream_enabled <= 1;
                        normalised_stream_read_address <= address_i - LAST_INPUT_ADDRESS;
                    end
                end

                BIND_WRITE_ADDRESS: begin
                    if (addressing_inputs) begin
                        stream_enabled <= 1;
                        normalised_stream_write_address <= address_i - START_ADDRESS;
                    end
                end

                // STREAM: begin
                //     if(stream_enabled) begin
                //         input_memory[normalised_stream_write_address] <= value;

                //         // need to replace with index if multiple outputs
                //         stream_bus <= output_memory; 
                //      end
                // end
            endcase
        end else if (!interface_enable & (instruction_i == BIND_INTERRUPT)) begin
            interrupt_enabled <= 0;
        end
        // end else if (!interface_enable & (instruction == (BIND_READ_ADDRESS | BIND_WRITE_ADDRESS))) begin
            // stream_enabled <= 0;
        // end
    end


    assign result_o = output_val_internal;

endmodule