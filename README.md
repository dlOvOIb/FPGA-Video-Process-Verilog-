# FPGA-Video-Process-Verilog-
# FPGA视频处理模块


## 0 FPGA视频处理介绍
FPGA视频数据来源有很多，可以从摄像头、HDMI接口灯多种信号源接入，“进入 FPGA 后都会被统一转化为标准的视频流时序（如 VESA/DVP 时序），即包含像素数据（data）、场同步（vs）、行同步（hs）以及数据有效使能（de）的同步信号组。

我将FPGA的视频处理分为两类：流水线处理和非流水线处理。

线性是指输入一个像素，处理完后直接输出一个像素，通常是对视频进行颜色处理或是涉及到窗口扫描操作的处理。开发难度较低。

非流水线处理则是类似对图像进行旋转、FFT等需要完整或大部分图像数据的操作，一般这类处理需要外接DDR3等器件来存储完整图像数据。开发难度较高。

## 1 视频仿真
FPGA代码综合、布线到上板通常需要十几分钟，而且查BUG也很困难，因此仿真是很重要的一环，能极大提升开发效率

仿真的核心部分有两项：模拟视频输入和处理结果输出

### 1.1 视频输入模块
该模块将bmp格式图片输出为dvi格式

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
### 1.2 视频输出模块
将dvi视频数据保存为bmp格式

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
## 2 线性图像处理模块

### 2.1 颜色处理
#### 2.1.1 RGB转灰度
将24位RGB视频数据转为8位灰度数据

该模块采用的方法为将 RGB 转换为 YCbCr 色彩空间中的 Y 分量，标准浮点数公式是
$$Y = 0.299 \times R + 0.587 \times G + 0.114 \times B$$

先将其放大256倍
$$0.299 \times 256 = 76.544 \approx 77$$

$$0.587 \times 256 = 150.272 \approx 150$$

$$0.114 \times 256 = 29.184 \approx 29$$

所以公式就变成了
$$Y = \frac{R \times 77 + G \times 150 + B \times 29}{256}$$

而除以256就直接以右移8位来执行

这样处理就可以将浮点乘法和除法转为硬件友好的形式了

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
![RGB转灰度结果图](./Sim_result/RGB2Gray.png)

#### 2.1.2 灰度转二值图
将8位灰度视频数据转为1位二值数据

module Gray_to_Binary(
        input  wire         clk,
        input  wire         rst_n,

        input  wire [7:0]   threshold,

        input  wire         vs_i,
        input  wire         hs_i,
        input  wire         de_i,
        input  wire [7:0]   data_i, 

        output  wire        vs_o,
        output  wire        hs_o,
        output  wire        de_o,
        output  wire        data_o
    );

![RGB转灰度结果图](./Sim_result/RGB2Binary.png)
### 2.2 形态学处理

### 2.3 滤波器

## 3 非线性图像处理模块