`default_nettype none

module tt_um_arkiss_titan #( parameter MAX_COUNT = 24'd10_000_000 ) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    reg [7:0] rx_byte_i, tx_byte_o;
	wire rx_valid_w;

    wire pll_sys_clock_r, pll_spi_clock_r, spi_pico_i, spi_poci_o, spi_cs_i;
    assign {pll_sys_clock_r, pll_spi_clock_r, spi_pico_i, spi_poci_o, spi_cs_i} = ui_in[7:3];

	spi_byte_if spi_interface_cvonk (
		.sysClk(pll_sys_clock_r), .SCLK(pll_spi_clock_r),
		.MOSI(spi_pico_i), .MISO(spi_poci_o), .SS(spi_cs_i),
		.tx(tx_byte_o), .rx(rx_byte_i), .rxValid(rx_valid_w)
	);

	// internal buses used to interface with the cores
	reg [7:0] internal_bus_instruction;
	reg [23:0] internal_bus_address;
	reg [31:0] internal_bus_value, internal_bus_result;
	wire [31:0] internal_bus_stream_w;

	instruction_handler internal_ih (
		.clk_i(pll_sys_clock_r), .spi_rx_valid_i(rx_valid_w), .spi_rx_byte_i(rx_byte_i),
		.result_i(internal_bus_result), .stream_i(internal_bus_stream_w),
		.instruction_o(internal_bus_instruction), .address_o(internal_bus_address),
		.value_o(internal_bus_value), .spi_tx_byte_o(tx_byte_o)
	);

	core_interface # (
		.TOTAL_INPUTS(2), .TOTAL_OUTPUTS(1), .START_ADDRESS(0), .END_ADDRESS(2)
	) ci_adder (
		.clk_i(pll_sys_clock_r), .instruction_i(internal_bus_instruction), .address_i(internal_bus_address),
		.value_i(internal_bus_value), .result_o(internal_bus_result), .stream_o(internal_bus_stream_w)
	);

    // wire reset = ! rst_n;
    // wire [6:0] led_out;
    // assign uo_out[6:0] = led_out;
    // assign uo_out[7] = 1'b0;

    // // use bidirectionals as outputs
    // assign uio_oe = 8'b11111111;

    // // put bottom 8 bits of second counter out on the bidirectional gpio
    // assign uio_out = second_counter[7:0];

    // // external clock is 10MHz, so need 24 bit counter
    // reg [23:0] second_counter;
    // reg [3:0] digit;

    // // if external inputs are set then use that as compare count
    // // otherwise use the hard coded MAX_COUNT
    // wire [23:0] compare = ui_in == 0 ? MAX_COUNT: {6'b0, ui_in[7:0], 10'b0};

    // always @(posedge clk) begin
    //     // if reset, set counter to 0
    //     if (reset) begin
    //         second_counter <= 0;
    //         digit <= 0;
    //     end else begin
    //         // if up to 16e6
    //         if (second_counter == compare) begin
    //             // reset
    //             second_counter <= 0;

    //             // increment digit
    //             digit <= digit + 1'b1;

    //             // only count from 0 to 9
    //             if (digit == 9)
    //                 digit <= 0;

    //         end else
    //             // increment counter
    //             second_counter <= second_counter + 1'b1;
    //     end
    // end

    // instantiate segment display
    // seg7 seg7(.counter(digit), .segments(led_out));

endmodule
