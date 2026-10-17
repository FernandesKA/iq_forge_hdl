`timescale 1ns/1ns

module irq_ctrl #(
    parameter int N = 2                 // число источников
)(
    input  logic           i_clk,
    input  logic           i_rst_n,     // синхронный, активный низкий
    input  logic [N-1:0]   i_event,     // импульсы в 1 такт от источников
    input  logic [N-1:0]   i_enable,    // маска из регистра IRQ_ENABLE
    input  logic [N-1:0]   i_clr,       // W1C: биты, в которые записали 1 (действует 1 такт)
    input  logic [N-1:0]   i_force,     // IRQ_FORCE: биты, в которые записали 1 (1 такт)
    output logic [N-1:0]   o_status,    // содержимое IRQ_STATUS
    output logic           o_irq        // уровень в PS, регистровый
);

logic [N-1: 0] status;

genvar i;
generate
    for (i = 0; i < N; i++) begin : g_bit
        always_ff @(posedge i_clk) begin
            if (!i_rst_n)
                status[i] <= 1'b0;
            else if (i_event[i] | i_force[i])
                status[i] <= 1'b1;
            else if (i_clr[i])
                status[i] <= i_force[i] ? 1'b1 : 1'b0;
        end
    end
endgenerate

always_ff @(posedge i_clk) begin
    if (!i_rst_n)
        o_irq <= 1'b0;
    else
        o_irq <= |(status & i_enable);
end

assign o_status = status;

endmodule
