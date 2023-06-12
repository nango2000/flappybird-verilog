`timescale  1ns/1ns




module LFSR(

    input               rst_n,    /*rst_n is necessary to prevet locking up*/
    input               clk,      /*clock signal*/
	 input               bird_ctrl,
//    input               load,     /*load seed to rand_num,active high */
//    input      [7:0]    seed,     
    output wire [7:0]    rand_num_out 

);

reg [7:0]    rand_num;
reg [7:0]    seed = 8'b1111111;

always@(negedge bird_ctrl)//通过按键来控制seed
	
	 if(!bird_ctrl)
         seed    <=seed - 1'b1;
	 else if(seed==1'b0)
			seed = 8'b1111111;
	 else seed <= seed;
		

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        rand_num    <=seed;
//    else if(load)
//        rand_num <=seed;    /*load the initial value when load is active*/
    else
        begin
            rand_num[0] <= rand_num[7];
            rand_num[1] <= rand_num[0];
            rand_num[2] <= rand_num[1];
            rand_num[3] <= rand_num[2];
            rand_num[4] <= rand_num[3]^rand_num[7];
            rand_num[5] <= rand_num[4]^rand_num[7];
            rand_num[6] <= rand_num[5]^rand_num[7];
            rand_num[7] <= rand_num[6];

               
            

        end
end

assign rand_num_out = (rand_num<8'd240)?rand_num:8'd240;

endmodule
