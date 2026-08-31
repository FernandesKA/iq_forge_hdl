`timescale 1ns/1ns

module fb_clk_recv (
    input logic i_clk_n,
    input logic i_clk_p,
    output logic o_clk
); 

   logic clk_se;

   IBUFDS IBUFDS_inst (
      .O(clk_se),   // 1-bit output: Buffer output
      .I(i_clk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB(i_clk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
   );

    BUFG BUFG_inst (
      .O(o_clk), // 1-bit output: Clock output.
      .I(clk_se)  // 1-bit input: Clock input.
   );

endmodule