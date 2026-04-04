`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/04 13:44:33
// Design Name: 
// Module Name: RGB_to_Gray
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RGB_to_Gray(
        input  wire        clk,
        input  wire        rst_n,

        input  wire        vs_i,
        input  wire        hs_i,
        input  wire        de_i,
        input  wire [23:0] data_i, 

        output  wire        vs_o,
        output  wire        hs_o,
        output  wire        de_o,
        output  wire [7:0] data_o
    );

    wire [7:0] r = data_i[23:16];
    wire [7:0] g = data_i[15:8];
    wire [7:0] b = data_i[7:0];

    // 加法寄存器 (18bit防溢出)
    reg [17:0] sum;
    
    // 输出寄存器
    reg [7:0]  gray;

    // 乘法寄存器 (8bit * 8bit = 16bit)
    reg [15:0] r_mult;
    reg [15:0] g_mult;
    reg [15:0] b_mult;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_mult <= 16'd0;
            g_mult <= 16'd0;
            b_mult <= 16'd0;
            sum    <= 18'd0;
            gray   <= 8'd0;
        end else begin
            // 对三个通道乘系数
            r_mult <= r * 8'd77;
            g_mult <= g * 8'd150;
            b_mult <= b * 8'd29;
            // 合并
            sum <= r_mult + g_mult + b_mult;
            // 右移 8 位提取灰度值
            gray <= sum[15:8];
        end
    end

    // 控制信号打拍 (3拍延迟)
    // 定义 3 位宽的移位寄存器，每一位代表延迟一拍
    reg [2:0] vs_d;
    reg [2:0] hs_d;
    reg [2:0] de_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vs_d <= 3'd0;
            hs_d <= 3'd0;
            de_d <= 3'd0;
        end else begin
            vs_d <= {vs_d[1:0], vs_i};
            hs_d <= {hs_d[1:0], hs_i};
            de_d <= {de_d[1:0], de_i};
        end
    end

    // 输出赋值
    // 提取移位寄存器的最高位（即延迟了 3 拍的信号）与第 3 拍产生的数据对齐
    assign vs_o   = vs_d[2];
    assign hs_o   = hs_d[2];
    assign de_o   = de_d[2];
    assign data_o = gray;

endmodule
