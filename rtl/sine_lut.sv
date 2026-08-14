`timescale 1ns/1ns

module sine_lut  #(
    parameter int ACC_WIDTH = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 12
) (
    input logic i_clk,
    input logic i_rst_n,
    input logic [ACC_WIDTH - 1 : 0] i_phase,
    output logic signed  [DATA_WIDTH - 1 : 0] o_i,
    output logic signed  [DATA_WIDTH - 1 : 0] o_q
);

    typedef enum logic [1:0] {
        quad_0 = 2'b00,
        quad_1 = 2'b01,
        quad_2 = 2'b10,
        quad_3 = 2'b11
    } quadrant_num;

    typedef struct packed {
        logic [1:0] quadrant;
        logic [LUT_ADDR_WIDTH - 3 : 0] addr_in_quadrant;
    } counter_packed;

    typedef union packed {
        logic [LUT_ADDR_WIDTH - 1 : 0] raw;
        counter_packed fields;
    } counter_union;

    localparam logic [ACC_WIDTH - 1 : 0] QUARTER_TURN = (ACC_WIDTH'(1)) << (ACC_WIDTH - 2);

    // channel 0 = I (cos), channel 1 = Q (sin)
    logic [ACC_WIDTH - 1 : 0] channel_phase [0 : 1];
    assign channel_phase[0] = i_phase + QUARTER_TURN;
    assign channel_phase[1] = i_phase;

    counter_union bram_cntr [0 : 1];
    logic [LUT_ADDR_WIDTH - 3 : 0] bram_addr [0 : 1];
    logic [DATA_WIDTH - 1 : 0] bram_value [0 : 1];
    logic [1 : 0] sign_quadrant [0 : 1];

    logic [DATA_WIDTH - 1 : 0] rom [0 : (2 ** (LUT_ADDR_WIDTH - 2)) - 1];

    initial begin
        $readmemh("rtl/sine_lut.hex", rom);
    end

    genvar ch;
    generate
        for (ch = 0; ch < 2; ch++) begin : g_channel

            assign bram_cntr[ch] = channel_phase[ch][ACC_WIDTH - 1 -: LUT_ADDR_WIDTH];

            always_ff @( posedge i_clk, negedge i_rst_n ) begin : rom_block
                if (!i_rst_n) begin
                    bram_value[ch] <= 0;
                    sign_quadrant[ch] <= 0;
                end else begin
                    bram_value[ch] <= rom[bram_addr[ch]];
                    sign_quadrant[ch] <= bram_cntr[ch].fields.quadrant;
                end
            end

            always_comb begin : signal_addressor
                case (bram_cntr[ch].fields.quadrant)
                    quad_0: bram_addr[ch] = bram_cntr[ch].fields.addr_in_quadrant;
                    quad_1: bram_addr[ch] = ~bram_cntr[ch].fields.addr_in_quadrant;
                    quad_2: bram_addr[ch] = bram_cntr[ch].fields.addr_in_quadrant;
                    quad_3: bram_addr[ch] = ~bram_cntr[ch].fields.addr_in_quadrant;
                    default: bram_addr[ch] = 0;
                endcase
            end

        end
    endgenerate

    always_comb begin : signal_inverter_i
        if (sign_quadrant[0][1]) begin
            o_i = (~bram_value[0]) + 1;
        end else begin
            o_i = (bram_value[0]);
        end
    end

    always_comb begin : signal_inverter_q
        if (sign_quadrant[1][1]) begin
            o_q = (~bram_value[1]) + 1;
        end else begin
            o_q = (bram_value[1]);
        end
    end

endmodule
