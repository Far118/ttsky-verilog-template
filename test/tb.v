/*
 * tb.v — тестбенч для tt_um_qwen_pe_array
 * Проверяет: загрузку весов (4x8), подачу активаций и чтение результата.
 * Референс: weights = identity 4x4 (w[k][k]=1), acts = [4,8,12,16],
 *           result[n] = act[n] * 1 = [4, 8, 12, 16] (int32).
 */
`default_nettype none
`timescale 1ns/1ps

module tb ();
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    tt_um_qwen_pe_array user_project (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // 100 МГц
    always #5 clk = ~clk;

    // Вспомогательные задачи
    task load_weight(input [2:0] row, input [1:0] col, input [3:0] w);
        begin
            uio_in = {4'b0000, row[2:0]};   // row через uio_in[2:0]
            ui_in  = {2'b00, col[1:0], w[3:0]}; // mode=00, col, weight
            #10;
            ui_in = 8'h00; uio_in = 8'h00;
            #10;
        end
    endtask

    task load_act(input [2:0] row, input [5:0] a);
        begin
            uio_in = {4'b0000, row[2:0]};
            ui_in  = {2'b01, a[5:0]};       // mode=01, activation
            #10;
            ui_in = 8'h00; uio_in = 8'h00;
            #10;
        end
    endtask

    initial begin
        clk = 0; ena = 1; rst_n = 0;
        ui_in = 0; uio_in = 0;
        $monitor("t=%0t ui_in=%b uio_in=%b uo_out=%h uio_out=%b", $time, ui_in, uio_in, uo_out, uio_out);
        #20 rst_n = 1;
        #20;

        // 1. Загрузка весов (identity: w[k][k]=1 для k=0..3)
        load_weight(0, 0, 4'sd1);
        load_weight(1, 1, 4'sd1);
        load_weight(2, 2, 4'sd1);
        load_weight(3, 3, 4'sd1);

        // 2. Подача активаций: a[0]=4, a[1]=8, a[2]=12, a[3]=16
        //    (act_data = {ui_in[5:0], 2'b00} => ui = act/4)
        load_act(0, 6'd1);
        load_act(1, 6'd2);
        load_act(2, 6'd3);
        load_act(3, 6'd4);

        // 3. act_last — флаг конца вектора
        ui_in = 8'b10_000000; uio_in = 8'h00;
        #10;
        ui_in = 8'h00;

        // 4. Ждём result_valid, читаем uo_out (старший байт int32 результата)
        #300;
        $display("uo_out=%h uio_out=%h", uo_out, uio_out);
        $finish;
    end

    // Dump для просмотра
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end
endmodule
