// ============================================================
// tt_um_qwen_pe_array.v — обёртка демо-чипа под стандартный пиннаут
// Tiny Tapeout (sky130 MPW shuttle). Демонстратор 4x8 систолического
// массива (INT4 веса x INT8 активации).
// ============================================================

`default_nettype none

module tt_um_qwen_pe_array (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire        ena,
    input  wire        clk,
    input  wire        rst_n
);

    localparam N = 4;
    localparam K = 8;
    localparam ACC_WIDTH = 32;

    wire                   weight_load_en = ena && (ui_in[7:6] == 2'b00);
    wire [$clog2(K)-1:0]   weight_row_addr = uio_in[3:0];
    wire [$clog2(N)-1:0]   weight_col_addr = ui_in[5:4];
    wire signed [3:0]      weight_data     = ui_in[3:0];

    wire                   act_valid = ena && (ui_in[7:6] == 2'b01);
    wire [$clog2(K)-1:0]   act_row_addr = uio_in[3:0];
    wire signed [7:0]      act_data = {ui_in[5:0], 2'b00};
    wire                   act_last = ui_in[7:6] == 2'b10;

    wire                        result_valid;
    wire signed [ACC_WIDTH-1:0] result [0:N-1];

    systolic_array #(.N(N), .K(K), .ACC_WIDTH(ACC_WIDTH)) core (
        .clk(clk), .rst_n(rst_n),
        .weight_load_en(weight_load_en),
        .weight_row_addr(weight_row_addr),
        .weight_col_addr(weight_col_addr),
        .weight_data(weight_data),
        .act_valid(act_valid),
        .act_row_addr(act_row_addr),
        .act_data(act_data),
        .act_last(act_last),
        .result_valid(result_valid),
        .result(result)
    );

    reg [$clog2(N)-1:0] out_col;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out_col <= 0;
        else if (result_valid)
            out_col <= (out_col == N-1) ? 0 : out_col + 1'b1;
    end

    assign uo_out = result_valid ? result[out_col][ACC_WIDTH-1 -: 8] : 8'h00;
    assign uio_out = {7'b0, result_valid};
    assign uio_oe  = 8'b0000_0001;

    wire _unused = &{uio_in[7:4], 1'b0};

endmodule
