module hdmi_top (
  input clk,  // 27 Mhz
  input sys_resetn,

  // HDMI TX
  output       tmds_clk_n,
  output       tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p,

  // UART
  input  ser_rx,
  output ser_tx
);

wire clk_p;     // VGA pixel clock: 25.2 Mhz
wire clk_p5;    // 5x pixel clock: 126 Mhz
wire pll_lock;

wire uart_valid;
wire uart_ready;
wire [31:0] uart_addr;
wire [31:0] uart_wdata;
wire [3:0] uart_wstrb;
wire [31:0] uart_rdata;

Gowin_rPLL u_pll (
  .clkin(clk),
  .clkout(clk_p5),
  .lock(pll_lock)
);

Gowin_CLKDIV u_div_5 (
    .clkout(clk_p),
    .hclkin(clk_p5),
    .resetn(pll_lock)
);

wire svo_term_valid;
assign svo_term_valid = 1'b0;  // (uart_valid && uart_ready) & (~uart_addr[2]) & uart_wstrb[0];

svo_hdmi_top u_hdmi (
	.clk(clk_p),
	.resetn(sys_resetn),

	// video clocks
	.clk_pixel(clk_p),
	.clk_5x_pixel(clk_p5),
	.locked(pll_lock),

	.term_in_tvalid( svo_term_valid ),
	.term_out_tready(),
	.term_in_tdata( /* uart_wdata[7:0] */ ),

	// output signals
	.tmds_clk_n(tmds_clk_n),
	.tmds_clk_p(tmds_clk_p),
	.tmds_d_n(tmds_d_n),
	.tmds_d_p(tmds_d_p)
);

endmodule