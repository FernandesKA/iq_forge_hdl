module sine_lut  #(
    parameter int ACC_WIDTH = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 12
) (
    input logic i_clk,
    input logic i_rst_n,
    input logic [ACC_WIDTH - 1 : 0] i_phase,
    output logic signed  [DATA_WIDTH - 1 : 0] o_amplitude
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

    counter_union bram_cntr;

    assign bram_cntr = i_phase[ACC_WIDTH - 1 -: LUT_ADDR_WIDTH];

    logic [LUT_ADDR_WIDTH - 3 : 0] bram_addr;
    logic [DATA_WIDTH - 1 : 0] bram_value;
    logic [1 : 0] sign_quadrant;

    logic [DATA_WIDTH - 1 : 0] rom [0 : (2 ** (LUT_ADDR_WIDTH - 2)) - 1];

    initial begin
        $readmemh("rtl/sine_lut.hex", rom);
    end

    always_ff @( posedge i_clk, negedge i_rst_n ) begin : rom_block
        if (!i_rst_n) begin
            bram_value <= 0;
            sign_quadrant <= 0;
        end else begin
            bram_value <= rom[bram_addr];
            sign_quadrant <= bram_cntr.fields.quadrant;
        end
    end

    always_comb begin : signal_addressor
        case (bram_cntr.fields.quadrant)
            quad_0: bram_addr = bram_cntr.fields.addr_in_quadrant;
            quad_1: bram_addr = ~bram_cntr.fields.addr_in_quadrant;
            quad_2: bram_addr = bram_cntr.fields.addr_in_quadrant;
            quad_3: bram_addr = ~bram_cntr.fields.addr_in_quadrant;
            default: bram_addr = 0;
        endcase
    end

    always_comb begin : signal_inverter
        if (sign_quadrant[1]) begin
            o_amplitude = (~bram_value) + 1;
        end else begin
            o_amplitude = (bram_value);
        end
    end

endmodule