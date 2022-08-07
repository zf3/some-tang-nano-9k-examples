/*
 * PSRAM example for Sipeed Tang Nano 9K.
 * Feng Zhou, 2022
 *
 * This shows example usage of the internal PSRAM of GW1NR-9CQN88P fpga 
 * on Tang Nano 9K. It simply writes a byte 8'b10010011 to address 0, reads it 
 * back and displays the lower 6 bits on LED.
 */

module psram_top (
    input sys_clk,  // 27 Mhz, crystal clock from board
    input sys_resetn,
    input button,   // 0 when pressed

    output reg [5:0] led,

    output [CS_WIDTH-1:0] O_psram_ck,       // These ports are needed, or the PSRAM IP will not compile
    output [CS_WIDTH-1:0] O_psram_ck_n,
    inout [CS_WIDTH-1:0] IO_psram_rwds,
    inout [DQ_WIDTH-1:0] IO_psram_dq,
    output [CS_WIDTH-1:0] O_psram_reset_n,
    output [CS_WIDTH-1:0] O_psram_cs_n 
);

localparam  DQ_WIDTH = 16;
localparam  CS_WIDTH = 2;

wire clk;           // 74.25 Mhz master clock

// PLL to generate 148.5 Mhz memory_clk
Gowin_rPLL pll( .clkout(memory_clk), .lock(pll_lock), .clkoutd(clk_d), .clkin(sys_clk));

reg [63:0] wr_data;
wire [63:0] rd_data;
wire rd_data_valid;
reg [20:0] addr;
reg cmd;
reg cmd_en;
reg [7:0] data_mask;

// HS PSRAM IP (version 1, single channel)
// All settings are set to default, except "burst length" which is 16
PSRAM_Memory_Interface_HS_Top psram(
    .clk(sys_clk), .memory_clk(memory_clk), .pll_lock(pll_lock), .rst_n(sys_resetn),
    .O_psram_ck(O_psram_ck), .O_psram_ck_n(O_psram_ck_n), .IO_psram_rwds(IO_psram_rwds),
    .IO_psram_dq(IO_psram_dq), .O_psram_reset_n(O_psram_reset_n), .O_psram_cs_n(O_psram_cs_n),
    .addr(addr), .wr_data(wr_data), .rd_data(rd_data), .rd_data_valid(rd_data_valid),
    .cmd(cmd), .cmd_en(cmd_en), .data_mask(data_mask),
    .clk_out(clk), .init_calib(calib)
);

reg state;           // 0: write a byte, 1: read the byte back
reg [5:0] cycle;     // 14 cycles between write and read
reg [7:0] read_back;
reg [7:0] read_count;
reg [5:0] read_cycles;

always @(posedge clk) begin
    if (!sys_resetn) begin
        state <= 1'b0;
        cycle <= 8'b0;
        cmd_en <= 0;
        read_cycles <= 0;
        read_back <= 0;
    end else begin
        // Show memory read result.  
        // When button (S2 on board) is pressed, show latency in cycles
        // Read takes 22 cycles. Write takes 14
        led <= button ? ~read_back[5:0] : ~read_cycles;
        if (calib) begin
            if (state == 1'b0) begin
                // write state
                cycle <= cycle + 6'b1;
                if (cycle == 13) begin      // IPUG 943 - Table 4-2, Tcmd is 14 when burst==16
                    cycle <= 8'b0;
                    state <= 1'b1;          // move to read state
                end
                // Burst size 16 => 4 cycle
                if (cycle == 0) begin
                    addr <= 0;
                    wr_data <= {56'b0, 8'b10010011};
                    // write byte 0 on 1st cycle
                    data_mask <= ~8'h01;
                    cmd <= 1'b1;
                    cmd_en <= 1'b1;
                end else begin
                    // mask off all other cycles
                    cmd_en <= 1'b0;
                    data_mask <= 8'hff;
                end
            end else begin
                // read state
                if (cycle != 8'b11_1111)
                    cycle <= cycle + 6'b1;
                if (cycle == 0) begin
                    addr <= 0;
                    cmd <= 1'b0;
                    cmd_en <= 1'b1;
                    data_mask <= 8'h00;
                    read_count <= 0;
                end else begin
                    cmd_en <= 1'b0;
                    if (rd_data_valid) begin
                        read_count <= read_count + 8'b1;
                        if (read_count == 0)
                            read_back <= rd_data[7:0];
                        if (read_count == 3)
                            read_cycles <= cycle;
                    end
                end
            end
        end
    end
end


endmodule