`timescale 1ns / 1ps

module sim_video_out #(
    // 不是固定分辨率，而是“最大支持分辨率”（用于开辟内存池）
    parameter MAX_IMG_W = 1920, 
    parameter MAX_IMG_H = 1080,
    parameter FILE_PATH = "D:/FPGA/0Video_process/FPGA-Video-Process-Verilog-/output_dynamic.bmp"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vs_i,   // 场同步
    input  wire        hs_i,   // 行同步
    input  wire        de_i,   // 数据有效
    input  wire [23:0] data_i, 
    output reg         frame_done 
);

    // ==========================================================
    // 二维内存池 (以最大分辨率开辟，实际使用多少视输入而定)
    // ==========================================================
    reg [23:0] out_mem [0 : MAX_IMG_W * MAX_IMG_H - 1];
    
    // 边沿检测
    reg vs_r, hs_r;
    always @(posedge clk) begin
        if (!rst_n) begin
            vs_r <= 1'b0; hs_r <= 1'b0;
        end else begin
            vs_r <= vs_i; hs_r <= hs_i;
        end
    end
    
    wire vs_rising = (vs_i && !vs_r);
    wire hs_rising = (hs_i && !hs_r);

    // 计算实际输出的宽高
    integer x_cnt, y_cnt;
    integer real_w, real_h;
    integer total_pixels;
    
    reg line_active;  // 标记当前行是否有数据
    reg capture_done; // 抓取完成标志

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0; y_cnt <= 0; 
            real_w <= 0; real_h <= 0;
            total_pixels <= 0; 
            line_active <= 0;
            frame_done <= 0;
            capture_done <= 0;
        end else begin
            frame_done <= 0; 

            // 如果还没抓完一帧，就继续抓
            if (!capture_done) begin
                
                // 1. VS 场同步：判断是新帧开始，还是本帧结束
                if (vs_rising) begin
                    if (total_pixels > 0) begin
                        // 如果已经收到了像素，说明上一帧结束了！立刻冻结状态
                        frame_done <= 1'b1;
                        capture_done <= 1'b1;
                        real_h <= y_cnt; // 最终的高度，就是累加的有效行数
                    end else begin
                        // 如果还没收到像素，说明这是仿真刚开始的复位脉冲
                        x_cnt <= 0; y_cnt <= 0;
                        real_w <= 0; real_h <= 0;
                        line_active <= 0;
                    end
                end 
                else begin
                    // 2. HS 行同步：强制 X 归零，Y 移至下一行
                    if (hs_rising) begin
                        x_cnt <= 0;
                        if (line_active) begin
                            y_cnt <= y_cnt + 1; // 只有当前行真有数据，Y 才加 1
                            line_active <= 0;
                        end
                    end

                    // 3. DE 数据有效：写入内存池，并动态更新最大宽度
                    if (de_i) begin
                        line_active <= 1'b1;
                        total_pixels <= total_pixels + 1;
                        
                        // 动态更新图像的实际宽度 (取最大的 x_cnt)
                        if (x_cnt + 1 > real_w) begin
                            real_w <= x_cnt + 1;
                        end
                        
                        // 写入内存池 (注意这里乘的是 MAX_IMG_W，保证物理地址不串行)
                        if (y_cnt < MAX_IMG_H && x_cnt < MAX_IMG_W) begin
                            out_mem[y_cnt * MAX_IMG_W + x_cnt] <= data_i;
                        end
                        
                        x_cnt <= x_cnt + 1;
                    end
                end
            end
        end
    end

    // 写文件线程 (使用动态侦测到的 real_w 和 real_h)
    integer file, x, y, p;
    integer row_stride, pad_bytes, pixel_size, file_size;
    
    initial begin
        @(posedge frame_done);
        #100; // 等待抓取逻辑完全稳定
        
        $display("=================================================");
        $display("【sim_video_out】get whole frame!!");
        $display(" real W and H : %0d x %0d", real_w, real_h);
        $display(" effective pixels   : %0d", total_pixels);
        if (total_pixels != real_w * real_h) begin
            $display("[Warning] frame is incomplete", total_pixels, real_w * real_h);
        end
        $display("=================================================");
        
        file = $fopen(FILE_PATH, "wb");
        if (file == 0) $display("[ERROR] can't create file %s", FILE_PATH);
        
        // 使用动态侦测到的 real_w 计算行字节对齐
        row_stride = ((real_w * 3) + 3) / 4 * 4;
        pad_bytes  = row_stride - (real_w * 3);
        pixel_size = row_stride * real_h;
        file_size  = 54 + pixel_size;
        
        // --- 写入 54 字节 BMP 头部 (动态宽高) ---
        $fwrite(file, "%c%c", 8'h42, 8'h4D); 
        $fwrite(file, "%c%c%c%c", file_size[7:0], file_size[15:8], file_size[23:16], file_size[31:24]); 
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", real_w[7:0], real_w[15:8], real_w[23:16], real_w[31:24]); 
        $fwrite(file, "%c%c%c%c", real_h[7:0], real_h[15:8], real_h[23:16], real_h[31:24]); 
        $fwrite(file, "%c%c", 8'h01, 8'h00);                   
        $fwrite(file, "%c%c", 8'h18, 8'h00);                   
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", pixel_size[7:0], pixel_size[15:8], pixel_size[23:16], pixel_size[31:24]); 
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 
        $fwrite(file, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); 

        // 写入像素数据
        for (y = real_h - 1; y >= 0; y = y - 1) begin
            for (x = 0; x < real_w; x = x + 1) begin
                $fwrite(file, "%c", out_mem[y * MAX_IMG_W + x][7:0]);   // B
                $fwrite(file, "%c", out_mem[y * MAX_IMG_W + x][15:8]);  // G
                $fwrite(file, "%c", out_mem[y * MAX_IMG_W + x][23:16]); // R
            end
            // 补齐 4 字节对齐
            for (p = 0; p < pad_bytes; p = p + 1) begin
                $fwrite(file, "%c", 8'h0);
            end
        end
        
        $fclose(file);
        $display("[TB] save successfully!: %s", FILE_PATH);
    end

endmodule