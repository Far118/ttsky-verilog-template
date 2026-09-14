// ============================================================
// systolic_array.v — NxK weight-stationary массив умножения матрица-на-вектор
// out[n] = sum_k( act[k] * weight[k][n] )
// (int4 веса, int8 активации, int32 аккумулятор)
// ============================================================

module systolic_array #(
    parameter N = 4,
    parameter K = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,

    input  wire                        weight_load_en,
    input  wire [$clog2(K)-1:0]        weight_row_addr,
    input  wire [$clog2(N)-1:0]        weight_col_addr,
    input  wire signed [3:0]           weight_data,

    input  wire                        act_valid,
    input  wire [$clog2(K)-1:0]        act_row_addr,
    input  wire signed [7:0]           act_data,
    input  wire                        act_last,

    output reg                         result_valid,
    output wire signed [ACC_WIDTH-1:0] result [0:N-1]
);

    wire signed [7:0]           act_bus    [0:K-1];
    wire signed [ACC_WIDTH-1:0] psum_wire  [0:K][0:N-1];
    reg  [K-1:0]                weight_row_sel;
    reg  [N-1:0]                weight_col_sel;

    always @(*) begin
        weight_row_sel = {K{1'b0}};
        weight_col_sel = {N{1'b0}};
        if (weight_load_en) begin
            weight_row_sel[weight_row_addr] = 1'b1;
            weight_col_sel[weight_col_addr] = 1'b1;
        end
    end

    genvar rk;
    generate
        for (rk = 0; rk < K; rk = rk + 1) begin : ACT_LATCH
            reg signed [7:0] act_reg;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    act_reg <= 8'sd0;
                else if (act_valid && act_row_addr == rk)
                    act_reg <= act_data;
            end
            assign act_bus[rk] = act_reg;
        end
    endgenerate

    genvar gn0;
    generate
        for (gn0 = 0; gn0 < N; gn0 = gn0 + 1) begin : PSUM0
            assign psum_wire[0][gn0] = {ACC_WIDTH{1'b0}};
        end
    endgenerate

    genvar prk, pcn;
    generate
        for (prk = 0; prk < K; prk = prk + 1) begin : GEN_ROW
            for (pcn = 0; pcn < N; pcn = pcn + 1) begin : GEN_COL
                pe_int4x8 #(.ACC_WIDTH(ACC_WIDTH)) pe_inst (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .weight_load_en (weight_row_sel[prk] && weight_col_sel[pcn]),
                    .weight_in      (weight_data),
                    .act_in         (act_bus[prk]),
                    .psum_in        (psum_wire[prk][pcn]),
                    .act_out        (),
                    .psum_out       (psum_wire[prk+1][pcn])
                );
            end
        end
    endgenerate

    genvar gn;
    generate
        for (gn = 0; gn < N; gn = gn + 1) begin : OUT
            assign result[gn] = psum_wire[K][gn];
        end
    endgenerate

    reg [1:0] delay_sr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_sr     <= 2'b00;
            result_valid <= 1'b0;
        end else begin
            delay_sr[0]  <= (act_valid && act_last);
            delay_sr[1]  <= delay_sr[0];
            result_valid <= delay_sr[1];
        end
    end

endmodule
