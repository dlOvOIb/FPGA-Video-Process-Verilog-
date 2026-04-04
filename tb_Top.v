`timescale 1ns / 1ps

module tb_Top();

    // 全局时钟与复位
    reg clk;
    reg rst_n;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
    end
    always #10 clk = ~clk; // 50MHz

    // 输入图像尺寸参数
    parameter IMG_W = 1280; 
    parameter IMG_H = 720;

    // 例化输入模块 (sim_video_in)
    wire        in_vs;
    wire        in_hs;
    wire        in_de;
    wire [31:0] in_data; // {8'h00, R, G, B}

    sim_video_in #(
        .IMG_W(IMG_W), 
        .IMG_H(IMG_H),
        .FILE_PATH("D:/FPGA/0Video_process/FPGA-Video-Process-Verilog-/1280x720.bmp")
    ) u_sim_video_in (
        .clk   (clk),
        .rst_n (rst_n),
        .vs_o  (in_vs),
        .hs_o  (in_hs),
        .de_o  (in_de),
        .data_o(in_data)
    );

    wire        gray_vs;
    wire        gray_hs;
    wire        gray_de;
    wire [7:0]  gray_data;

    RGB_to_Gray RGB_to_Gray(
        .clk(clk),
        .rst_n(rst_n),

        .vs_i(in_vs),
        .hs_i(in_hs),
        .de_i(in_de),
        .data_i(in_data), 

        .vs_o(gray_vs),
        .hs_o(gray_hs),
        .de_o(gray_de),
        .data_o(gray_data)
    );

    wire        binary_vs;
    wire        binary_hs;
    wire        binary_de;
    wire        binary_data;

    RGB_to_Binary RGB_to_Binary(
        .clk(clk),
        .rst_n(rst_n),
        .threshold(8'd127),
        .vs_i(gray_vs),
        .hs_i(gray_hs),
        .de_i(gray_de),
        .data_i(gray_data), 

        .vs_o(binary_vs),
        .hs_o(binary_hs),
        .de_o(binary_de),
        .data_o(binary_data)
    );

    


    // 例化输出模块 (sim_video_out)
    wire out_frame_done; // 接收模块的一帧结束标志

    sim_video_out #(
        .IMG_W(IMG_W), 
        .IMG_H(IMG_H),
        .FILE_PATH("D:/FPGA/0Video_process/FPGA-Video-Process-Verilog-/Sim_result/output.bmp")
    ) u_sim_video_out (
        .clk        (clk),
        .rst_n      (rst_n),
        .vs_i       (binary_vs),
        .hs_i       (binary_hs),     
        .de_i       (binary_de),
        .data_i     ({binary_data*24'hFFFFFF}),
        .frame_done (out_frame_done) // 连出完成信号
    );

    // 处理结束
    initial begin
        @(posedge out_frame_done); // 死等一帧输出完成
        #100; // 稍等几拍，确保文件 io 操作彻底闭环
        $display("[TB] Successful！");
        $finish;
    end

    // 兜底超时防死锁分支
    initial begin
        #50_000_000;
        $display("[TB] ERROR!!!! timeout");
        $finish;
    end

endmodule