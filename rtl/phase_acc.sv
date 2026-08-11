`timescale 1ns/1ns

module phase_acc #(parameter ACC_WIDTH = 24
) (
    input i_clk,
    input i_rst_n,
    input i_ce,
    input [ACC_WIDTH-1:0] i_ftw,
    output [ACC_WIDTH-1:0] o_phase
);
    
    logic [ACC_WIDTH - 1 : 0] phase_reg;

    always_ff @(posedge i_clk, negedge i_rst_n) begin
        if (!i_rst_n) begin
                phase_reg <= 0;
            end else begin
                if (i_ce)
                    phase_reg <= phase_reg + i_ftw;
                else
                    phase_reg <= phase_reg;
            end
    end


    assign o_phase = phase_reg;

endmodule // phase acc