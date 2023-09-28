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
    // assign {pll_sys_clock_r, pll_spi_clock_r, spi_pico_i, spi_poci_o, spi_cs_i} = ui_in[7:3];

    assign pll_sys_clock_r = clk;
    assign pll_spi_clock_r = ui_in[7];
    assign spi_pico_i = ui_in[6];
    assign spi_cs_i = ui_in[5];

    assign spi_poci_o = uo_out[7];

    assign uo_out[6:0] = 7'b0;
    assign uio_out[7:0] = 8'b0;
    assign uio_oe[7:0] = 8'b0;

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

endmodule
