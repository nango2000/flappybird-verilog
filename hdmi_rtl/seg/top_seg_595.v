`timescale  1ns/1ns


module  top_seg_595
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号，低电平有效
	 
	 input   wire    [19:0]  data        ,	

    output  wire            stcp        ,   //输出数据存储寄时钟
    output  wire            shcp        ,   //移位寄存器的时钟输入
    output  wire            ds          ,   //串行数据输入
    output  wire            oe              //输出使能信号
);

//********************************************************************//
//******************** Parameter And Internal Signal *****************//
//********************************************************************//
//wire  define
//wire    [19:0]  data    ;   //数码管要显示的值
wire    [5:0]   point   ;   //小数点显示,高电平有效top_seg_595
reg            seg_en  ;   //数码管使能信号，高电平有效
wire            sign    ;   //符号位，高电平显示负号

//********************************************************************//
//**************************** Main Code *****************************//
//********************************************************************//
//-------------data_gen_inst--------------
//data_gen    data_gen_inst
//(
//    .sys_clk     (sys_clk  ),   //系统时钟，频率50MHz
//    .sys_rst_n   (sys_rst_n),   //复位信号，低电平有效
//    
//    .data        (data     ),   //数码管要显示的值
//    .point       (point    ),   //小数点显示,高电平有效
//    .seg_en      (seg_en   ),   //数码管使能信号，高电平有效
//    .sign        (sign     )    //符号位，高电平显示负号
//);


assign point = 6'b000_000;
assign  sign    =   1'b0;

always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        seg_en  <=  1'b0;
    else
        seg_en  <=  1'b1;

//-------------seg7_dynamic_inst--------------
seg_595_dynamic    seg_595_dynamic_inst
(
    .sys_clk    (sys_clk   ),   //系统时钟，频率50MHz
    .sys_rst_n  (sys_rst_n ),   //复位信号，低有效
    .data       (data      ),   //数码管要显示的值
    .point      (point     ),   //小数点显示,高电平有效
    .seg_en     (seg_en    ),   //数码管使能信号，高电平有效
    .sign       (sign      ),   //符号位，高电平显示负号

    .stcp       (stcp      ),   //输出数据存储寄时钟
    .shcp       (shcp      ),   //移位寄存器的时钟输入
    .ds         (ds        ),   //串行数据输入
    .oe         (oe        )    //输出使能信号
);
endmodule
