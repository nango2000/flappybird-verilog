`timescale  1ns/1ns


module  beep
#(
    parameter   TIME_500MS =   25'd12499999,   //0.5s计数值
    parameter   DO  =   18'd95420 ,   //"哆"音调分频计数值（频率262）
    parameter   RE  =   18'd85034 ,   //"来"音调分频计数值（频率294）
    parameter   MI  =   18'd75757 ,   //"咪"音调分频计数值（频率330）
    parameter   FA  =   18'd71633 ,   //"发"音调分频计数值（频率349）
    parameter   SO  =   18'd63775 ,   //"梭"音调分频计数值（频率392）
    parameter   LA  =   18'd56818 ,   //"拉"音调分频计数值（频率440）
    parameter   XI  =   18'd50607     //"西"音调分频计数值（频率494）
)
(
    input   wire        sys_clk     ,   //系统时钟,频率50MHz
    input   wire        sys_rst_n   ,   //系统复位，低有效
	 
	 input   wire        score_flag,
	 
	 input wire          bird_ctrl,
	 input wire          is_gameover,
	 
    output  reg         beep            //输出蜂鸣器控制信号
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//reg   define
reg     [24:0]  cnt         ;   //0.5s计数器
reg     [17:0]  freq_cnt    ;   //音调计数器
reg     [2:0]   cnt_500ms   ;   //0.5s个数计数
reg     [17:0]  freq_data   ;   //音调分频计数值

//wire  define
wire    [16:0]  duty_data   ;   //占空比计数值

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//设置50％占空比：音阶分频计数值的一半即为占空比的高电平数
assign  duty_data   =   freq_data   >>    1'b1;

//cnt:0.5s循环计数器
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt <=  25'd0;
    else    if(cnt <TIME_500MS&&is_gameover==1'b1)
        cnt <=   cnt +   1'b1;
    else
        cnt <=  1'b0;

//cnt_500ms：对500ms个数进行计数，每个音阶鸣叫时间0.5s，7个音节一循环
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_500ms   <=  3'd0;
//    else    if(cnt == TIME_500MS &&is_gameover==1'b1&& cnt_500ms ==  4)
//        cnt_500ms   <=  4'd8;
    else    if(cnt == TIME_500MS&&is_gameover==1'b1&&cnt_500ms<=3'd4)
        cnt_500ms   <=  cnt_500ms + 1'b1;

//不同时间鸣叫不同的音阶
//always@(posedge sys_clk or  negedge sys_rst_n)
//    if(sys_rst_n == 1'b0)
//        freq_data   <=  DO;
//    else    case(cnt_500ms)
//        0:  freq_data   <=   DO;
//        1:  freq_data   <=   RE;
//        2:  freq_data   <=   MI;
//        3:  freq_data   <=   FA;
//        4:  freq_data   <=   SO;
//        5:  freq_data   <=   LA;
//        6:  freq_data   <=   XI;
//        default:  freq_data   <=   1'b0;
//    endcase

always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
       freq_data    <=  18'd0;
	 else if(score_flag == 1'b1&&is_gameover==1'b0)
	    freq_data    <= SO;	  
	 else if(bird_ctrl == 1'b0&&is_gameover==1'b0)
       freq_data    <= DO;    
    else    case(cnt_500ms)
        1:  freq_data   <=   XI;
        2:  freq_data   <=   SO;
        3:  freq_data   <=   MI;
        4:  freq_data   <=   DO;
        default:  freq_data   <=   1'b0;
    endcase
	 




//freq_cnt：当计数到音阶计数值或跳转到下一音阶时，开始重新计数
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        freq_cnt    <=  18'd0;
    else    if(freq_cnt == freq_data || cnt == TIME_500MS)
        freq_cnt    <=  18'd0;
    else
        freq_cnt    <=  freq_cnt +  1'b1;

//beep：输出蜂鸣器波形
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        beep    <=  1'b0;
    else    if(freq_cnt >= duty_data)
        beep    <=  1'b1;
    else
        beep    <=  1'b0;

endmodule
