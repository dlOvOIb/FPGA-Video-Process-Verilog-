`timescale 1ns / 1ps

module sim_video_in #(
    // 图像数据参数 (默认 720p)
    parameter IMG_W = 1280, 
    parameter IMG_H = 720,
    parameter FILE_PATH = "D:/FPGA/0_Python/input.bmp",

    // ==========================================================
    // 标准视频时序参数 (1280x720 @ 60Hz)
    // ==========================================================
    parameter H_ACTIVE = 1280, // 水平有效像素
    parameter H_FP     = 110,  // 行前肩
    parameter H_SYNC   = 40,   // 行同步
    parameter H_BP     = 220,  // 行后肩
    
    parameter V_ACTIVE = 720,  // 垂直有效行
    parameter V_FP     = 5,    // 场前肩
    parameter V_SYNC   = 5,    // 场同步
    parameter V_BP     = 20,   // 场后肩
    
    parameter HS_POL   = 1'b1, // 行同步极性 (1:正极性)
    parameter VS_POL   = 1'b1  // 场同步极性 (1:正极性)
)(
    input  wire        clk,
    input  wire        rst_n,
    
    output reg         vs_o,
    output reg         hs_o,   
    output reg         de_o,
    output reg  [31:0] data_o
);

    // 读取 BMP 数据 (24/32bit 动态自适应兼容)
    reg [7:0] file_buf [0 : (IMG_W * 4 + 3) * IMG_H + 2048]; 
    reg [31:0] pixel_mem [0 : IMG_W*IMG_H - 1];
    
    integer file, r, x, y, idx;
    integer data_offset, row_stride, real_w, real_h, bit_count, bpp;

    initial begin
        file = $fopen(FILE_PATH, "rb");
        if (file == 0) begin
            $display("[ERROR] can't open file %s", FILE_PATH);
            $stop;
        end else begin
            r = $fread(file_buf, file);
            $fclose(file);
            
            real_w = {file_buf[21], file_buf[20], file_buf[19], file_buf[18]};
            real_h = {file_buf[25], file_buf[24], file_buf[23], file_buf[22]};
            bit_count = {file_buf[29], file_buf[28]};
            bpp = (bit_count == 32) ? 4 : 3;

            data_offset = {file_buf[13], file_buf[12], file_buf[11], file_buf[10]};
            row_stride = ((IMG_W * bpp) + 3) / 4 * 4; 
            
            for (y = 0; y < IMG_H; y = y + 1) begin
                for (x = 0; x < IMG_W; x = x + 1) begin
                    idx = data_offset + (IMG_H - 1 - y) * row_stride + x * bpp;
                    pixel_mem[y * IMG_W + x] = {8'h00, file_buf[idx+2], file_buf[idx+1], file_buf[idx]};
                end
            end
            $display("[TB] get video data");
        end
    end

    // 视频时序发生器 (VTC)
    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [15:0] h_cnt;
    reg [15:0] v_cnt;

    // 二维扫描计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 0; // 一帧结束，场复位
                end else begin
                    v_cnt <= v_cnt + 1;
                end
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    // 生成纯组合逻辑的时序标志位
    wire h_act_flag = (h_cnt < H_ACTIVE);
    wire v_act_flag = (v_cnt < V_ACTIVE);
    
    wire h_sync_flag = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
    wire v_sync_flag = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);

    // 打拍输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hs_o   <= 0;
            vs_o   <= 0;
            de_o   <= 0;
            data_o <= 32'd0;
        end else begin
            // 极性控制
            hs_o <= HS_POL ? h_sync_flag : ~h_sync_flag;
            vs_o <= VS_POL ? v_sync_flag : ~v_sync_flag;
            
            // 数据有效区域
            de_o <= h_act_flag && v_act_flag;
            
            // 查表输出图像数据
            if (h_act_flag && v_act_flag) begin
                data_o <= pixel_mem[v_cnt * IMG_W + h_cnt];
            end else begin
                data_o <= 32'd0; // 消隐区输出黑屏
            end
        end
    end

endmodule