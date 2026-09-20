`timescale  1ns/1ns

module lfm_ftw_generator #(
        parameter int ACC_WIDTH = 24
    )(
        input logic i_clk,
        input logic i_rst_n,
        input logic i_load,
        input logic i_continious,
        input logic [ACC_WIDTH - 1 : 0] i_ftw_start,
        input logic [ACC_WIDTH - 1 : 0] i_ftw_stop,
        input logic [ACC_WIDTH - 1 : 0] i_ftw_incr,
        output logic [ACC_WIDTH - 1 : 0] o_ftw
    );

    logic [ACC_WIDTH - 1 : 0] ftw_counter;
    logic [ACC_WIDTH : 0] ftw_next;

    assign ftw_next = {1'b0, ftw_counter} + {1'b0, i_ftw_incr};

    always_ff @(posedge i_clk, negedge i_rst_n) begin
        if (~i_rst_n) begin
            ftw_counter <= 0;
        end else begin
            if (i_load) begin
                ftw_counter <= i_ftw_start;
            end else begin    
                if (i_continious)
                    ftw_counter <= ftw_counter + i_ftw_incr;
                else
                    ftw_counter <= (ftw_next < {1'b0, i_ftw_stop}) ? ftw_next[ACC_WIDTH - 1 : 0] : i_ftw_stop;
            end
        end
    end

    assign o_ftw = ftw_counter;

endmodule
