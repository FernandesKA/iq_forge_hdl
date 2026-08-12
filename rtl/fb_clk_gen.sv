`timescale 1ps/1ps

module fb_clk_gen(
    input logic i_clk,
    output logic o_fb_clk_n,
    output logic o_fb_clk_p
);

    logic oddr_q;

   ODDR #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE" 
      .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
      .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC" 
   ) ODDR_inst (
      .Q(oddr_q),   // 1-bit DDR output
      .C(i_clk),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D1(1'b0), // 1-bit data input (positive edge)
      .D2(1'b1), // 1-bit data input (negative edge)
      .R(0),   // 1-bit reset
      .S(0)    // 1-bit set
   );

   OBUFDS #(
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("SLOW")           // Specify the output slew rate
   ) OBUFDS_inst (
      .O(o_fb_clk_p),     // Diff_p output (connect directly to top-level port)
      .OB(o_fb_clk_n),   // Diff_n output (connect directly to top-level port)
      .I(oddr_q)      // Buffer input
   );

endmodule