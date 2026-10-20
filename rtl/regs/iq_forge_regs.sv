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

localparam logic [ADDR_W-3:0] A_ID         = 'h00 >> 2;
localparam logic [ADDR_W-3:0] A_VERSION    = 'h04 >> 2;
localparam logic [ADDR_W-3:0] A_SCRATCH    = 'h08 >> 2;
localparam logic [ADDR_W-3:0] A_CTRL       = 'h10 >> 2;
localparam logic [ADDR_W-3:0] A_CMD        = 'h14 >> 2;
localparam logic [ADDR_W-3:0] A_STATUS     = 'h18 >> 2;
localparam logic [ADDR_W-3:0] A_FTW        = 'h20 >> 2;
localparam logic [ADDR_W-3:0] A_LFM_START  = 'h30 >> 2;
localparam logic [ADDR_W-3:0] A_LFM_STOP   = 'h34 >> 2;
localparam logic [ADDR_W-3:0] A_LFM_INCR   = 'h38 >> 2;
localparam logic [ADDR_W-3:0] A_IRQ_STATUS = 'h40 >> 2;
localparam logic [ADDR_W-3:0] A_IRQ_ENABLE = 'h44 >> 2;
localparam logic [ADDR_W-3:0] A_IRQ_FORCE  = 'h48 >> 2;


logic [31:0]      scratch;
logic [3:0]       ctrl;
logic [FTW_W-1:0] ftw;
logic [FTW_W-1:0] lfm_start_sh;
logic [FTW_W-1:0] lfm_stop_sh;
logic [FTW_W-1:0] lfm_incr_sh;
logic [1:0]       irq_en;

logic [FTW_W-1:0] lfm_start;
logic [FTW_W-1:0] lfm_stop;
logic [FTW_W-1:0] lfm_incr;

logic             cmd_restart;
logic [1:0]       irq_clr;
logic [1:0]       irq_force;
logic [1:0]       irq_status;
logic             lfm_done_q;
logic             lfm_done_rise;

logic [31:0] wmask;

always_comb
    wmask = {{8{wr_strb[3]}}, {8{wr_strb[2]}}, {8{wr_strb[1]}}, {8{wr_strb[0]}}};


always_comb begin : write_channel
    s_axi_awready = s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;
    s_axi_wready = s_axi_awready;

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

always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        scratch      <= '0;
        ftw          <= 24'h05_1EB8;
        ctrl         <= '0;
        lfm_start_sh <= 24'h05_1EB8;
        lfm_stop_sh  <= 24'h28_F5C0;
        lfm_incr_sh  <= 24'h00_002F;
        irq_en       <= '0;
    end else if (wr_en) begin
        case (wr_addr[ADDR_W-1:2])
            A_SCRATCH:    scratch      <= (scratch & ~wmask) | (wr_data & wmask);
            A_FTW:        ftw          <= (ftw & ~wmask[FTW_W-1:0]) | (wr_data[FTW_W-1:0] & wmask[FTW_W-1:0]);
            A_CTRL:       ctrl         <= (ctrl & ~wmask[3:0]) | (wr_data[3:0] & wmask[3:0]);
            A_LFM_START:  lfm_start_sh <= (lfm_start_sh & ~wmask[FTW_W-1:0]) | (wr_data[FTW_W-1:0] & wmask[FTW_W-1:0]);
            A_LFM_STOP:   lfm_stop_sh  <= (lfm_stop_sh & ~wmask[FTW_W-1:0]) | (wr_data[FTW_W-1:0] & wmask[FTW_W-1:0]);
            A_LFM_INCR:   lfm_incr_sh  <= (lfm_incr_sh & ~wmask[FTW_W-1:0]) | (wr_data[FTW_W-1:0] & wmask[FTW_W-1:0]);
            A_IRQ_ENABLE: irq_en       <= (irq_en & ~wmask[1:0]) | (wr_data[1:0] & wmask[1:0]);
            default: ;
        endcase
    end
end

always_comb begin : strobes
    cmd_restart = wr_en && wr_addr[ADDR_W-1:2] == A_CMD && wr_strb[0] && wr_data[0];
    irq_clr     = (wr_en && wr_addr[ADDR_W-1:2] == A_IRQ_STATUS && wr_strb[0]) ? wr_data[1:0] : '0;
    irq_force   = (wr_en && wr_addr[ADDR_W-1:2] == A_IRQ_FORCE  && wr_strb[0]) ? wr_data[1:0] : '0;
end

always_ff @(posedge s_axi_aclk) begin : lfm_active
    if (!s_axi_aresetn) begin
        lfm_start <= 24'h05_1EB8;
        lfm_stop  <= 24'h28_F5C0;
        lfm_incr  <= 24'h00_002F;
    end else if (!(ctrl[0] && ctrl[2]) || cmd_restart) begin
        lfm_start <= lfm_start_sh;
        lfm_stop  <= lfm_stop_sh;
        lfm_incr  <= lfm_incr_sh;
    end
end

always_ff @(posedge s_axi_aclk) begin : lfm_done_edge
    if (!s_axi_aresetn)
        lfm_done_q <= 1'b0;
    else
        lfm_done_q <= i_lfm_done;
end

assign lfm_done_rise = i_lfm_done & ~lfm_done_q;

irq_ctrl #(
    .N(2)
) u_irq_ctrl (
    .i_clk    (s_axi_aclk),
    .i_rst_n  (s_axi_aresetn),
    .i_event  ({1'b0, lfm_done_rise}),
    .i_enable (irq_en),
    .i_clr    (irq_clr),
    .i_force  (irq_force),
    .o_status (irq_status),
    .o_irq    (o_irq)
);

assign s_axi_arready = !s_axi_rvalid;
assign s_axi_rresp   = 2'b00;

always_ff @(posedge s_axi_aclk) begin : read_channel
    if (!s_axi_aresetn) begin
        s_axi_rvalid <= 1'b0;
        s_axi_rdata  <= '0;
    end else if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1'b1;
        case (s_axi_araddr[ADDR_W-1:2])
            A_ID:         s_axi_rdata <= ID;
            A_VERSION:    s_axi_rdata <= VERSION;
            A_SCRATCH:    s_axi_rdata <= scratch;
            A_CTRL:       s_axi_rdata <= {28'b0, ctrl};
            A_STATUS:     s_axi_rdata <= {31'b0, i_lfm_done};
            A_FTW:        s_axi_rdata <= {{(32-FTW_W){1'b0}}, ftw};
            A_LFM_START:  s_axi_rdata <= {{(32-FTW_W){1'b0}}, lfm_start_sh};
            A_LFM_STOP:   s_axi_rdata <= {{(32-FTW_W){1'b0}}, lfm_stop_sh};
            A_LFM_INCR:   s_axi_rdata <= {{(32-FTW_W){1'b0}}, lfm_incr_sh};
            A_IRQ_STATUS: s_axi_rdata <= {30'b0, irq_status};
            A_IRQ_ENABLE: s_axi_rdata <= {30'b0, irq_en};
            default:      s_axi_rdata <= '0;
        endcase
    end else if (s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
    end
end

always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin : dds_rst
    if (!s_axi_aresetn)
        o_dds_rst_n <= 1'b0;
    else
        o_dds_rst_n <= ~ctrl[1];
end

assign o_dds_en         = ctrl[0];
assign o_dds_mode       = ctrl[2];
assign o_lfm_continious = ctrl[3];
assign o_lfm_load       = cmd_restart;
assign o_ftw            = ftw;
assign o_lfm_start      = lfm_start;
assign o_lfm_stop       = lfm_stop;
assign o_lfm_incr       = lfm_incr;


endmodule
