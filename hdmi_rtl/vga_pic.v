`timescale  1ns/1ns

module  vga_pic
(
    input   wire            vga_clk     ,   //输入工作时钟,频率25MHz
    input   wire            sys_rst_n   ,   //输入复位信号,低电平有效
    input   wire    [9:0]  pix_x       ,   //输入VGA有效显示区域像素点X轴坐标
    input   wire    [9:0]  pix_y       ,   //输入VGA有效显示区域像素点Y轴坐标
	 input   wire           bird_ctrl   ,

    output  wire     [15:0]  pix_data_out,        //输出像素点色彩信息
	 output  reg            is_gameover,
	 output  wire      beep, 
	 output  reg      [19:0]     score 
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter   H_VALID =   10'd640 ,   //行有效数据
            V_VALID =   10'd480 ;   //场有效数据
				
parameter   H_bird  =   10'd34,
				W_bird  =   10'd27,
				bird_size=  13'd918,
				
				H_pipe_body  =   6'd48,
				W_pipe_body  =   1'b1,
				pipe_body_size =  6'd48,
				
				H_pipe_head  =   6'd52,
				W_pipe_head  =   6'd24,
				pipe_head_size =  11'd1248,
				
				pipe_x1 = 10'd464,       //管道起始位置
				//pipe_len = 10'd150,     //管道长度
				pipe_gap = 10'd110,      //管道空隙
				
				H_land  =   9'd312,
				W_land  =   4'd14,
				land_size =  13'd4368,
				
				land_x1 = 10'd420,      //地平面
				
				H_bg    =   10'd288,    //背景宽度
				bg_x    =   10'd176;    //背景起始

parameter   RED     =   16'hF800,   //红色
            ORANGE  =   16'hFC00,   //橙色
            YELLOW  =   16'hFFE0,   //黄色
            GREEN   =   16'h07E0,   //绿色
            CYAN    =   16'h07FF,   //青色
            BLUE    =   16'h001F,   //蓝色
            PURPPLE =   16'hF81F,   //紫色
            BLACK   =   16'h0000,   //黑色
            WHITE   =   16'hFFFF,   //白色
            GRAY    =   16'hD69A,   //灰色
				
				land_1color  =   16'h51c8,
				land_2color  =   16'he7f1,
				land_3color  =   16'h5404,
				land_4color  =   16'hd549,
				land_5color  =   16'hded2,
					
				bgcolor =   16'h4E19;

parameter   speed1   = 2'd1;
			
//wire  define
wire            rd_en_bird       ;   //ROM读使能
wire            rd_en_pipe_body       ;   //ROM读使能
wire            rd_en_pipe_body2      ;
wire            rd_en_pipe_head       ;   //ROM读使能
wire            rd_en_land            ;
wire            rd_en_black           ;
wire            hit_det;

wire    [15:0]  pic_data_bird    ;   //自ROM读出的图片数据
wire    [15:0]  pic_data_pipe_body    ;   //自ROM读出的图片数据
wire    [15:0]  pic_data_pipe_body2    ;
wire    [15:0]  pic_data_pipe_head    ;
wire    [15:0]  pic_data_pipe_head2    ;
wire    [15:0]  pic_data_land   ;

wire     [7:0]   rand_num;
wire             rand_clk; //由pipe_move_flag控制 

wire     [15:0]  pix_data_out_ori;
wire     [15:0]  pix_data_out_pro;
//reg   define
reg     [9:0]   rom_addr_bird    ;   //读ROM地址
reg             pic_valid_bird   ;       //图片数据有效信号

reg     [5:0]   rom_addr_pipe_body    ;  //读ROM地址
reg             pic_valid_pipe_body   ;  //图片数据有效信号
reg     [5:0]   rom_addr_pipe_body2    ;  //读ROM地址
reg             pic_valid_pipe_body2   ;  //图片数据有效信号

reg     [10:0]  rom_addr_pipe_head    ;  //读ROM地址
reg             pic_valid_pipe_head   ;  //图片数据有效信号
reg     [10:0]  rom_addr_pipe_head2    ;  //读ROM地址
reg             pic_valid_pipe_head2   ;  //图片数据有效信号

reg     [12:0]  rom_addr_land    ;  //读ROM地址
reg             pic_valid_land   ;  //图片数据有效信号

reg             pic_valid_black  ;

reg     [15:0]  pix_data         ;       //背景色彩信息

reg     [9:0]   pipe_move        ; //移动信号
reg             pipe_move_flag   ;

reg     [9:0]   pipe_move2        ; //移动信号
reg             pipe_move_flag2   ;
reg             pipe_move_delay   ;

reg     [4:0]   land_move        ; //移动信号
reg             land_move_flag   ;

reg     [6:0]   bird_ctrl_cnt    ;
reg     [9:0]   bird_move        ;
reg     [4:0]   bird_speed       ;
reg             bird_move_flag   ;
reg             is_gamestart      ;

reg     [7:0]   pipe_len;
reg     [7:0]   pipe_len2;

reg     [1:0]   score_flag;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//pix_data:输出像素点色彩信息,根据当前像素点坐标指定当前像素点颜色数据

//rd_en:ROM读使能
assign  rd_en_bird = ((pix_x >= (((H_VALID - H_bird)/2) - 1'b1))
                && (pix_x < (((H_VALID - H_bird)/2) + H_bird - 1'b1)) 
                && (pix_y >= (V_VALID -W_bird - bird_move -1'b1 ))
                && (pix_y < (V_VALID- bird_move - 1'b1)));
					 
assign  rd_en_pipe_body = (((pix_x >= (pipe_x1 - pipe_move - 1'b1 + 2'd2))
                && (pix_x < (pipe_x1 + H_pipe_body - pipe_move - 1'b1 + 2'd2)) 
                && (pix_y >= 1'b0)
                && (pix_y < (1'b0 + pipe_len - 1'b1)))
					 || ((pix_x >= (pipe_x1 - pipe_move - 1'b1 + 2'd2))
                && (pix_x < (pipe_x1 + H_pipe_body - pipe_move - 1'b1 + 2'd2))
					 && (pix_y >= (1'b0 + pipe_len + 2'd2*W_pipe_head + pipe_gap - 1'b1))
                && (pix_y < (1'b0 + land_x1 - 1'b1)))
					 );
					 
assign  rd_en_pipe_body2 = (((pix_x >= (pipe_x1 - pipe_move2 - 1'b1 + 2'd2 ))
                && (pix_x < (pipe_x1 + H_pipe_body - pipe_move2 - 1'b1 + 2'd2)) 
                && (pix_y >= 1'b0)
                && (pix_y < (1'b0 + pipe_len2 - 1'b1)))
					 || ((pix_x >= (pipe_x1 - pipe_move2 - 1'b1 + 2'd2))
                && (pix_x < (pipe_x1 + H_pipe_body - pipe_move2 - 1'b1 + 2'd2))
					 && (pix_y >= (1'b0 + pipe_len2 + 2'd2*W_pipe_head + pipe_gap - 1'b1))
                && (pix_y < (1'b0 + land_x1 - 1'b1)))
					 );
					 
assign  rd_en_pipe_head = (((pix_x >= (pipe_x1 - pipe_move - 1'b1))
                && (pix_x < (pipe_x1 + H_pipe_head - pipe_move - 1'b1)) 
                && (pix_y >= (pipe_len - 1'b1))
                && (pix_y < (pipe_len + W_pipe_head - 1'b1)))
					 || ((pix_x >= (pipe_x1 - pipe_move - 1'b1))
                && (pix_x < (pipe_x1 + H_pipe_head - pipe_move - 1'b1))
					 && (pix_y >= (1'b0 + pipe_len + W_pipe_head + pipe_gap - 1'b1))
                && (pix_y < (1'b0 + pipe_len + 2'd2*W_pipe_head + pipe_gap - 1'b1)))
					 );

assign  rd_en_pipe_head2 = (((pix_x >= (pipe_x1 - pipe_move2 - 1'b1))
                && (pix_x < (pipe_x1 + H_pipe_head - pipe_move2 - 1'b1)) 
                && (pix_y >= (pipe_len2 - 1'b1))
                && (pix_y < (pipe_len2 + W_pipe_head - 1'b1)))
					 || ((pix_x >= (pipe_x1 - pipe_move2 - 1'b1))
                && (pix_x < (pipe_x1 + H_pipe_head - pipe_move2 - 1'b1))
					 && (pix_y >= (1'b0 + pipe_len2 + W_pipe_head + pipe_gap - 1'b1))
                && (pix_y < (1'b0 + pipe_len2 + 2'd2*W_pipe_head + pipe_gap - 1'b1)))
					 );
					 
assign  rd_en_land = ((pix_x >= (bg_x - land_move - 1'b1))
                && (pix_x < (bg_x + H_land - land_move - 1'b1)) 
                && (pix_y >= (land_x1 -1'b1 + 3'd4))
                && (pix_y < (land_x1 -1'b1 + 5'd18))	 
					 );
				
assign  rd_en_black = ((pix_x >= (bg_x + H_bg - 1'b1))
                || (pix_x < (bg_x - 1'b1))
					 );	

//碰撞检测
assign hit_det = ((bird_move <= 6'd60)
					||(V_VALID -W_bird - bird_move -1'b1 <= 1'b0)
					||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_body - pipe_move - 1'b1 + 2'd2))&&((((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move - 1'b1 + 2'd2))&&((V_VALID -W_bird - bird_move -1'b1)<=(pipe_len + W_pipe_head - 1'b1))&&((V_VALID -W_bird - bird_move -1'b1)>=(1'b0)))
					||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_body - pipe_move - 1'b1 + 2'd2))&&((((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move - 1'b1 + 2'd2))&&((V_VALID- bird_move - 1'b1)<=(land_x1 - 1'b1))&&((V_VALID- bird_move - 1'b1)>=(pipe_len + W_pipe_head + pipe_gap - 1'b1)))
               ||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_body - pipe_move2 - 1'b1 + 2'd2))&&((((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move2 - 1'b1 + 2'd2))&&((V_VALID -W_bird - bird_move -1'b1)<=(pipe_len2 + W_pipe_head - 1'b1))&&((V_VALID -W_bird - bird_move -1'b1)>=(1'b0)))
					||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_body - pipe_move2 - 1'b1 + 2'd2))&&((((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move2 - 1'b1 + 2'd2))&&((V_VALID- bird_move - 1'b1)<=(land_x1 - 1'b1))&&((V_VALID- bird_move - 1'b1)>=(pipe_len2 + W_pipe_head + pipe_gap - 1'b1)))
					);


					
always@(posedge vga_clk or negedge sys_rst_n)	 
	 if(sys_rst_n == 1'b0)
		 is_gameover <= 1'b0;
	 else if(hit_det == 1'b1)
//	 ||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_head - pipe_move - 1'b1) && (((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move - 1'b1))//上
//		&&((((V_VALID -W_bird - bird_move -1'b1)<=(pipe_len + W_pipe_head - 1'b1))&&((V_VALID -W_bird - bird_move -1'b1)>=(pipe_len - 1'b1)))||(((V_VALID- bird_move - 1'b1)<=(pipe_len + W_pipe_head - 1'b1))&&((V_VALID- bird_move - 1'b1)>=(pipe_len - 1'b1)))))
//		||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_head - pipe_move - 1'b1) && (((H_VALID - H_bird)/2) + H_bird - 1'b1)>=(pipe_x1 - pipe_move - 1'b1))//上
//		&&((((V_VALID -W_bird - bird_move -1'b1)<=(pipe_len + 2'd2*W_pipe_head + pipe_gap - 1'b1))&&((V_VALID -W_bird - bird_move -1'b1)>=(pipe_len + W_pipe_head + pipe_gap - 1'b1)))||(((V_VALID- bird_move - 1'b1)<=(pipe_len + 2'd2*W_pipe_head + pipe_gap - 1'b1))&&((V_VALID- bird_move - 1'b1)>=(pipe_len + W_pipe_head + pipe_gap - 1'b1)))))
//		||(((((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 + H_pipe_body - pipe_move - 1'b1 + 2'd2)&&(((H_VALID - H_bird)/2) + H_bird - 1'b1)<=(pipe_x1 - pipe_move - 1'b1 + 2'd2))&&(((V_VALID - bird_move -1'b1)<=(pipe_len - 1'b1))||((V_VALID -W_bird - bird_move -1'b1)>=(pipe_len + 2'd2*W_pipe_head + pipe_gap - 1'b1))))//柱	 
	   
	    is_gameover <= 1'b1;
//	 else
//		 is_gameover <= 1'b0;
		 
//游戏开始		 
always@(posedge vga_clk or negedge sys_rst_n)
	 if(sys_rst_n == 1'b0)
		 is_gamestart <= 1'b0;
	 else if(bird_ctrl == 1'b0)
	    is_gamestart <= 1'b1;

//管子长度 
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pipe_len   <=  8'd150;
    else if((pipe_move >= (H_bg + H_pipe_head))
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_len   <=  8'd50 + rand_num;
		
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pipe_len2   <=  8'd60 + rand_num;
    else if((pipe_move2 >= (H_bg + H_pipe_head))
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_len2   <=  8'd50 + rand_num;  		
	 					 
//pic_valid:图片数据有效信号
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_bird   <=  1'b1;
    else
        pic_valid_bird   <=  rd_en_bird;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_pipe_body   <=  1'b1;
    else
        pic_valid_pipe_body  <=  rd_en_pipe_body;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_pipe_body2   <=  1'b1;
    else
        pic_valid_pipe_body2  <=  rd_en_pipe_body2;		  

always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_pipe_head   <=  1'b1;
    else
        pic_valid_pipe_head  <=  rd_en_pipe_head;
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_pipe_head2   <=  1'b1;
    else
        pic_valid_pipe_head2  <=  rd_en_pipe_head2;	
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_land   <=  1'b1;
    else
        pic_valid_land  <=  rd_en_land;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pic_valid_black   <=  1'b1;
    else
        pic_valid_black  <=  rd_en_black;
		  
//背景		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pix_data    <= 16'd0;
    else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= 1'b0)
				&&(pix_y < (land_x1 -1'b1)))
        pix_data    <=  bgcolor;
	 else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= (land_x1 -1'b1))
				&&(pix_y < (land_x1 -1'b1 + 2'd2)))
        pix_data    <=  land_1color;
	 else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= (land_x1 -1'b1 + 2'd2))
				&&(pix_y < (land_x1 -1'b1 + 3'd4)))
        pix_data    <=  land_2color;
	 else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= (land_x1 -1'b1 + 5'd18))
				&&(pix_y < (land_x1 -1'b1 + 5'd20)))
        pix_data    <=  land_3color;
	 else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= (land_x1 -1'b1 + 5'd20))
				&&(pix_y < (land_x1 -1'b1 + 5'd22)))
        pix_data    <=  land_4color;
	 else    if((pix_x >= (bg_x - 1'b1)) 
				&& (pix_x < (bg_x +H_bg - 1'b1))
				&&(pix_y >= (land_x1 -1'b1 + 5'd20)))
        pix_data    <=  land_5color;
	
//移动信号
//管道
always@(posedge vga_clk or negedge sys_rst_n)
	 if(sys_rst_n == 1'b0)
		  pipe_move <= 10'd0;
	 else if((is_gameover== 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move <= pipe_move; 
	 else if((pipe_move_flag == 1'b1)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move <= pipe_move + speed1;
	 else if((pipe_move_flag == 1'b0)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move <= 1'b0;	  
		  
always@(posedge vga_clk or negedge sys_rst_n)	
	 if(sys_rst_n == 1'b0)
		  pipe_move_flag <= 1'b0;
	 else if(pipe_move == 10'd0)
	     pipe_move_flag <= 1'b1;
	 else if((pipe_move >= (H_bg + H_pipe_head))
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
	     pipe_move_flag <= 1'b0;
		  
always@(posedge vga_clk or negedge sys_rst_n)
	 if(sys_rst_n == 1'b0)
		  pipe_move2 <= 10'd0;
	 else if((is_gameover== 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move2 <= pipe_move2; 
	 else if((pipe_move_flag2 == 1'b1)&&(pipe_move_delay == 1'b0)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move2 <= pipe_move2 + speed1;
	 else if((pipe_move_flag2 == 1'b0)&&(pipe_move_delay == 1'b0)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move2 <= 1'b0;	  

always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
		  pipe_move_delay <= 1'b1;
	 else if((pipe_move == (H_bg + H_pipe_head)/2)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
	     pipe_move_delay <= 1'b0;

		  
always@(posedge vga_clk or negedge sys_rst_n)	
	 if(sys_rst_n == 1'b0)
		  pipe_move_flag2 <= 1'b0;
	 else if(pipe_move2 == 10'd0)
	     pipe_move_flag2 <= 1'b1;
	 else if((pipe_move2 >= (H_bg + H_pipe_head))
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  pipe_move_flag2 <= 1'b0;
			  
//分数			  
always@(posedge vga_clk or negedge sys_rst_n)			  
	if(sys_rst_n == 1'b0)begin
		  score <= 20'd0;
		  
	end
	else if(((pipe_move == (H_bg + H_pipe_head)/2)
			  ||(pipe_move2 == (H_bg + H_pipe_head)/2))
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1))&&is_gameover==1'b0)begin
			score <= score+1'b1;
			
	end
	else begin
         score <= score;
			
	end	   	

always@(posedge vga_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        score_flag <=  1'b0;
    else if(((pipe_move <= ((H_bg + H_pipe_head)/2+10'd10))&&(pipe_move >= ((H_bg + H_pipe_head)/2-10'd10)))
			  ||((pipe_move2 <= ((H_bg + H_pipe_head)/2+10'd10))&&(pipe_move2 >= ((H_bg + H_pipe_head)/2-10'd10))))        
			score_flag <= 1'b1;		
	else
         score_flag <= 1'b0;			
	
//地面
always@(posedge vga_clk or negedge sys_rst_n)
	 if(sys_rst_n == 1'b0)
		  land_move <= 1'b0;
	 else if((is_gameover== 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  land_move <= land_move; 
	 else if((land_move_flag == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  land_move <= land_move + speed1;
	 else if((land_move_flag == 1'b0)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  land_move <= 1'b0;
		  
always@(posedge vga_clk or negedge sys_rst_n)	
	 if(sys_rst_n == 1'b0)
		  land_move_flag <= 1'b0;
	 else if(land_move == 5'd0)
	     land_move_flag <= 1'b1;
	 else if((land_move == (H_land - H_bg -2'd2*speed1))//调整
	        &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
	     land_move_flag <= 1'b0;
		  
//鸟
always@(posedge vga_clk or negedge sys_rst_n)
	 if(sys_rst_n == 1'b0)
		  bird_move <= 10'd226;	 
	 else if((bird_move_flag == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  bird_move <= bird_move + bird_speed;
	 else if((is_gameover == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  bird_move <= bird_move;  
	 else if((bird_move_flag == 1'b0)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))
		  bird_move <= bird_move - bird_speed;

//上升或下降	  	  
always@(posedge vga_clk or negedge sys_rst_n)
	 if((sys_rst_n == 1'b0))
		  bird_move_flag <= 1'b0;
	 else if(bird_ctrl == 1'b0)
		  bird_move_flag <= 1'b1;
	 else if(bird_speed == 1'b0)
		  bird_move_flag <= 1'b0;

//控制速度		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)begin
		  bird_speed <= 1'b0;
		  bird_ctrl_cnt <= 1'b0;
		  end
    else if((is_gameover == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))begin
			bird_speed <= 5'd0;
			end		  
	 else if((bird_move_flag == 1'b1)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))begin	  
				if((bird_ctrl_cnt >=1'b0)&&(bird_ctrl_cnt < 5'd5))begin
					bird_speed <= 5'd6;
					bird_ctrl_cnt <= bird_ctrl_cnt + 1'b1;
					end
				else if((bird_ctrl_cnt >= 5'd5)&&(bird_ctrl_cnt < 5'd10))begin
					bird_speed <= 5'd4;
					bird_ctrl_cnt <= bird_ctrl_cnt + 1'b1;
					end
				else if((bird_ctrl_cnt >= 5'd10)&&(bird_ctrl_cnt < 5'd15))begin
					bird_speed <= 5'd2;
					bird_ctrl_cnt <= bird_ctrl_cnt + 1'b1;
					end
				else if((bird_ctrl_cnt >= 5'd15)&&(bird_ctrl_cnt < 5'd20))begin
					bird_speed <= 5'd1;
					bird_ctrl_cnt <= bird_ctrl_cnt + 1'b1;
					end
				else if((bird_ctrl_cnt == 5'd20))begin
				   bird_speed <= 5'd0;
					bird_ctrl_cnt <= 1'b0;
				   end			
		  end
	 else if((bird_move_flag == 1'b0)&&(is_gamestart == 1'b1)
	       &&(pix_x == (H_VALID - 1'b1))&&(pix_y == (V_VALID - 1'b1)))begin
			   
				if((bird_ctrl_cnt >=1'b0)&&(bird_ctrl_cnt < 5'd3))begin
					bird_speed <= bird_speed;
					bird_ctrl_cnt <= bird_ctrl_cnt + 1'b1;
					end
				else if((bird_ctrl_cnt == 5'd3))begin
				   bird_speed <= bird_speed + 1'b1;
					bird_ctrl_cnt <= 1'b0;
					end				
			end

//rom_addr:读ROM地址
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_bird    <=  10'd0;
    else    if(rom_addr_bird == (bird_size - 1'b1))
        rom_addr_bird    <=  10'd0;
    else    if(rd_en_bird == 1'b1)
        rom_addr_bird    <=  rom_addr_bird + 1'b1;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_pipe_body    <=  6'd0;
    else    if(rom_addr_pipe_body == (pipe_body_size - 1'b1))
        rom_addr_pipe_body   <=  6'd0;
    else    if(rd_en_pipe_body == 1'b1)
        rom_addr_pipe_body    <=  rom_addr_pipe_body + 1'b1;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_pipe_body2    <=  6'd0;
    else    if(rom_addr_pipe_body2 == (pipe_body_size - 1'b1))
        rom_addr_pipe_body2   <=  6'd0;
    else    if(rd_en_pipe_body2 == 1'b1)
        rom_addr_pipe_body2    <=  rom_addr_pipe_body2 + 1'b1;
		 
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_pipe_head    <=  10'd0;
    else    if(rom_addr_pipe_head == (pipe_head_size - 1'b1))
        rom_addr_pipe_head   <=  10'd0;
    else    if(rd_en_pipe_head == 1'b1)
        rom_addr_pipe_head    <=  rom_addr_pipe_head + 1'b1;
		  
always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_pipe_head2    <=  10'd0;
    else    if(rom_addr_pipe_head2 == (pipe_head_size - 1'b1))
        rom_addr_pipe_head2   <=  10'd0;
    else    if(rd_en_pipe_head2 == 1'b1)
        rom_addr_pipe_head2    <=  rom_addr_pipe_head2 + 1'b1;

always@(posedge vga_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rom_addr_land    <=  10'd0;
    else    if(rom_addr_land == (land_size - 1'b1))
        rom_addr_land   <=  10'd0;
    else    if(rd_en_land == 1'b1)
        rom_addr_land    <=  rom_addr_land + 1'b1;		  
		  
//pix_data_out:输出VGA显示图像数据
assign  pix_data_out_ori = ((pic_valid_black == 1'b1)?
								BLACK:((pic_valid_pipe_body == 1'b1) ? 
								pic_data_pipe_body : ((pic_valid_pipe_body2 == 1'b1) ?
							   pic_data_pipe_body2 : ((pic_valid_pipe_head == 1'b1) ?
								pic_data_pipe_head : ((pic_valid_pipe_head2 == 1'b1) ?
							   pic_data_pipe_head2 : ((pic_valid_bird == 1'b1) ?	
								pic_data_bird : ((pic_valid_land == 1'b1) ? 
								pic_data_land : pix_data))))))								
								);

assign  pix_data_out_pro[4:0] =  pix_data_out_ori[4:0]*30/100;
assign  pix_data_out_pro[10:5] =  pix_data_out_ori[10:5]*39/100;
assign  pix_data_out_pro[15:11] =  pix_data_out_ori[15:11]*11/100;




assign  pix_data_out = (is_gameover)?pix_data_out_pro:pix_data_out_ori;

								
assign rand_clk = pipe_move_flag+pipe_move_flag2;

		  
rom_bird rom_bird_inst
(
    .address    (rom_addr_bird   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_bird      ),  //输入读使能,1bit

    .q          (pic_data_bird   )   //输出读数据,16bit
);

rom_pipe_body rom_pipe_body_inst
(
    .address    (rom_addr_pipe_body   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_pipe_body      ),  //输入读使能,1bit

    .q          (pic_data_pipe_body   )   //输出读数据,16bit
);

rom_pipe_body rom_pipe_body2_inst
(
    .address    (rom_addr_pipe_body2   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_pipe_body2      ),  //输入读使能,1bit

    .q          (pic_data_pipe_body2   )   //输出读数据,16bit
);


rom_pipe_head rom_pipe_head_inst
(
    .address    (rom_addr_pipe_head   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_pipe_head      ),  //输入读使能,1bit

    .q          (pic_data_pipe_head   )   //输出读数据,16bit
);

rom_pipe_head rom_pipe_head2_inst
(
    .address    (rom_addr_pipe_head2   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_pipe_head2      ),  //输入读使能,1bit

    .q          (pic_data_pipe_head2   )   //输出读数据,16bit
);

rom_land rom_land_inst
(
    .address    (rom_addr_land   ),  //输入读ROM地址,14bit
    .clock      (vga_clk         ),  //输入读时钟,vga_clk,频率25MHz,1bit
    .rden       (rd_en_land      ),  //输入读使能,1bit

    .q          (pic_data_land  )   //输出读数据,16bit
);

LFSR LFSR_inst
(
    .bird_ctrl   (bird_ctrl),
    .rst_n       (sys_rst_n),    
    .clk         (rand_clk),           
    .rand_num_out(rand_num)
);

beep beep_inst
(
     .sys_clk     (vga_clk),   //系统时钟,频率50MHz
     .sys_rst_n   (sys_rst_n),   //系统复位，低有效	 
	  .bird_ctrl(bird_ctrl),
	  .score_flag(score_flag),
	  .is_gameover(is_gameover),
     .beep  (beep)            //输出蜂鸣器控制信号
);

endmodule
