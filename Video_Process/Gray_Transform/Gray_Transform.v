`timescale 1ns / 1ps

module Gray_Transform(
        input  wire         clk,
        input  wire         rst_n,

        input  wire         vs_i,
        input  wire         hs_i,
        input  wire         de_i,
        input  wire [7:0]   data_i, 

        output  wire        vs_o,
        output  wire        hs_o,
        output  wire        de_o,
        output  wire [7:0]  data_o
    );


    Gray_LUT u_Gray_LUT(
        .Gray_i 	(data_i  ),
        .Gray_o 	(data_o  )
    );
    

    // 控制信号打拍 (1拍延迟)
    reg  vs_d;
    reg  hs_d;
    reg  de_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vs_d <= 1'd0;
            hs_d <= 1'd0;
            de_d <= 1'd0;
        end else begin
            vs_d <= vs_i;
            hs_d <= hs_i;
            de_d <= de_i;
        end
    end

    // 输出赋值
    // 提取移位寄存器的最高位（即延迟了 3 拍的信号）与第 3 拍产生的数据对齐
    assign vs_o   = vs_d;
    assign hs_o   = hs_d;
    assign de_o   = de_d;

endmodule
