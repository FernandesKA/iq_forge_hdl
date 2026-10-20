`timescale 1ns/1ns

module iq_forge_regs #(
    parameter int          ADDR_W  = 12,             // окно 4 KiB
    parameter int          FTW_W   = 24,
    parameter logic [31:0] ID      = 32'h4951_4647,  // "IQFG"
    parameter logic [31:0] VERSION = 32'h0001_0000
)(
    input  logic              s_axi_aclk,
    input  logic              s_axi_aresetn,
    // AW
    input  logic [ADDR_W-1:0] s_axi_awaddr,
    input  logic [2:0]        s_axi_awprot,
    input  logic              s_axi_awvalid,
    output logic              s_axi_awready,
    // W
    input  logic [31:0]       s_axi_wdata,
    input  logic [3:0]        s_axi_wstrb,
    input  logic              s_axi_wvalid,
    output logic              s_axi_wready,
    // B
    output logic [1:0]        s_axi_bresp,
    output logic              s_axi_bvalid,
    input  logic              s_axi_bready,
    // AR
    input  logic [ADDR_W-1:0] s_axi_araddr,
    input  logic [2:0]        s_axi_arprot,
    input  logic              s_axi_arvalid,
    output logic              s_axi_arready,
    // R
    output logic [31:0]       s_axi_rdata,
    output logic [1:0]        s_axi_rresp,
    output logic              s_axi_rvalid,
    input  logic              s_axi_rready,
    // к dds_tx_chain
    output logic              o_dds_en,
    output logic              o_dds_rst_n,
    output logic              o_dds_mode,
    output logic              o_lfm_continious,
    output logic              o_lfm_load,
    output logic [FTW_W-1:0]  o_ftw,
    output logic [FTW_W-1:0]  o_lfm_start,
    output logic [FTW_W-1:0]  o_lfm_stop,
    output logic [FTW_W-1:0]  o_lfm_incr,
    input  logic              i_lfm_done,
    // в PS
    output logic              o_irq
);

logic wr_en;
logic [ADDR_W - 1 : 0] wr_addr;
logic [31:0] wr_data;
logic [3:0] wr_strb;

always_comb begin : write_channel
    s_axi_awready = s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;
    s_axi_wready = s_axi_wready;

    wr_en = s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready;
    wr_addr = s_axi_awaddr;
    wr_data = s_axi_wdata;
    wr_strb = s_axi_wstrb;
end

always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        s_axi_bvalid <= 1'b0;
        s_axi_bresp  <= 2'b00;
    end else if (wr_en) begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= 2'b00;      // OKAY
    end else if (s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
    end
end

endmodule
