// ============================================================
// pe_int4x8.v — один процессорный элемент (PE) систолического массива
// Weight-stationary: вес (int4) хранится в регистре PE весь проход,
// активация (int8) течёт "вправо", частичная сумма (int32) течёт "вниз".
//
// Формат чисел: two's complement, INT4 в диапазоне [-8..7], INT8 в [-128..127]
// ============================================================

module pe_int4x8 #(
    parameter ACC_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  weight_load_en,
    input  wire signed [3:0]     weight_in,

    input  wire signed [7:0]     act_in,
    input  wire signed [ACC_WIDTH-1:0] psum_in,

    output reg  signed [7:0]     act_out,
    output reg  signed [ACC_WIDTH-1:0] psum_out
);

    reg signed [3:0] weight_reg;

    wire signed [11:0] mult_result;
    assign mult_result = weight_reg * act_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= 4'sd0;
            act_out    <= 8'sd0;
            psum_out   <= {ACC_WIDTH{1'b0}};
        end else begin
            if (weight_load_en)
                weight_reg <= weight_in;

            act_out <= act_in;

            psum_out <= psum_in + $signed({{(ACC_WIDTH-12){mult_result[11]}}, mult_result});
        end
    end

endmodule
