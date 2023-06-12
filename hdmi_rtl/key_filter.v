`timescale  1ns/1ns

module  key_filter
(
		input wire sys_clk,
		input wire key_in,
		
		output reg key_out 

);

reg [19:0] cnt;

always@(posedge sys_clk)
	if(key_in == 1'b0) begin
	
		if(cnt < 20'd999999) begin
			cnt <= cnt + 1'b1;
		end
		else begin
			cnt <= cnt;
		end
		
		if(cnt <= 20'd999998) begin
			key_out <= 1'b1;
		end
		else begin
			key_out <= 1'b0;
		end
		
	end	
	else begin
		cnt <= 1'b0;
		key_out <= 1'b1;
	end
	
endmodule
