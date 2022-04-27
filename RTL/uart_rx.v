/*************************************************************/
//function: UART数据接收模块
//Author  : WangYuxiao
//Email   : wangyuxiao2000@bupt.edu.cn
//Data    : 2022.4.27
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ps

module uart_rx (clk,rst_n,rx_en,rx_clk,rx,data_out,data_out_valid,rx_clk_en,check_flag);
input clk;                  /*系统时钟*/
input rst_n;                /*低电平异步复位信号*/
input rx_en;                /*接收模块使能信号,高电平有效*/
input rx_clk;               /*接收模块波特率时钟*/
input rx;                   /*FPGA端UART接收口*/
output reg [7:0] data_out;  /*输出UART接收到的数据*/
output reg data_out_valid;  /*输出数据有效标志,高电平有效*/
output reg rx_clk_en;       /*接收模块波特率时钟使能信号,高电平有效*/
output reg check_flag;      /*校验标志位,当校验位存在且校验出错时,产生一个clk周期的高电平*/

/************************工作参数设置************************/
parameter data_bits=8;             /*定义数据位数,在5-8取值*/
parameter check_mode=1;            /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
/************************************************************/



/***********************检测起始位到来***********************/
wire start_flag;
reg rx_reg_0,rx_reg_1,rx_reg_2,rx_reg_3;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
	  rx_reg_0<=1'b0;
	  rx_reg_1<=1'b0;
	  rx_reg_2<=1'b0;
	  rx_reg_3<=1'b0;
	end
  else
    begin
	  rx_reg_0<=rx;
	  rx_reg_1<=rx_reg_0;
	  rx_reg_2<=rx_reg_1;
	  rx_reg_3<=rx_reg_2;	
	end
end

assign start_flag=(~rx_reg_2)&&rx_reg_3;
/************************************************************/



/*************************进行RX接收*************************/
reg [1:0] rx_state; /*UART接收状态机*/
reg [data_bits-1:0] data; 
reg [2:0] data_cnt;
reg bit_check;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
	  rx_state<=2'b00;
	  rx_clk_en<=1'b0;
	  data_cnt<=0;
	  data<=0;
	  data_out<=0;
	  data_out_valid<=1'b0; 
	  check_flag<=1'b0; 
	end
  else if (rx_en)
    begin
	  case(rx_state)
	    2'b00 : begin/*等待有效数据输入*/
		          if(start_flag)
					begin
	                  rx_state<=2'b01;
	                  rx_clk_en<=1'b1;
	                  data_cnt<=0;
	                  data<=0;
					  data_out<=0;
	                  data_out_valid<=1'b0; 
	                  check_flag<=1'b0;						  
					end
				  else
					begin
	                  rx_state<=2'b00;
	                  rx_clk_en<=1'b0;
	                  data_cnt<=0;
	                  data<=0;
					  data_out<=data_out;
	                  data_out_valid<=1'b0; 
	                  check_flag<=check_flag; 						
					end
		        end
	    2'b01 : begin/*接收起始位*/
		          if(rx_clk)
				    begin
	                  rx_state<=2'b11;
	                  rx_clk_en<=1'b1;
	                  data_cnt<=0;
	                  data<=0;
					  data_out<=0;
	                  data_out_valid<=1'b0; 
	                  check_flag<=1'b0;							  
					end
				  else
					begin
	                  rx_state<=rx_state;
	                  rx_clk_en<=rx_clk_en;
	                  data_cnt<=data_cnt;
	                  data<=data;
					  data_out<=data_out;
	                  data_out_valid<=data_out_valid;
	                  check_flag<=check_flag;
					end
		        end					
	    2'b11 : begin/*接收数据位*/
		          if(rx_clk)
					begin
	                  rx_clk_en<=1'b1;
					  data_out<=0;
	                  data_out_valid<=1'b0; 
	                  check_flag<=1'b0;	
                      if(data_cnt==data_bits-1)
                        begin
                          data_cnt<=0;	
                          data[data_cnt]<=rx;
                          rx_state<=2'b10;							  						  
                        end
                      else
                        begin
                          data_cnt<=data_cnt+1;	
                          data[data_cnt]<=rx;	
                          rx_state<=2'b11;							  
                        end									  
					end
				  else
					begin
	                  rx_state<=rx_state;
	                  rx_clk_en<=rx_clk_en;
	                  data_cnt<=data_cnt;
	                  data<=data;
					  data_out<=data_out;
	                  data_out_valid<=data_out_valid;
	                  check_flag<=check_flag;						
					end
		        end					
	    2'b10 : begin/*接收校验位或第一位停止位*/
		          if(rx_clk)
					begin
	                  rx_state<=2'b00;
	                  rx_clk_en<=1'b0;
	                  data_cnt<=0;
	                  data<=data;
					  data_out<=data;
	                  data_out_valid<=1'b1; 
					  if(bit_check==rx)
	                    check_flag<=1'b0;
                      else
   					    check_flag<=1'b1;
					end
				  else
					begin
	                  rx_state<=rx_state;
	                  rx_clk_en<=rx_clk_en;
	                  data_cnt<=data_cnt;
	                  data<=data;
					  data_out<=data_out;
	                  data_out_valid<=data_out_valid;
	                  check_flag<=check_flag;						  
					end
		        end
	  endcase
	end
  else
    begin
	  rx_state<=2'b00;
	  rx_clk_en<=1'b0;
	  data_cnt<=0;
	  data<=0;
	  data_out<=0;
	  data_out_valid<=1'b0; 
	  check_flag<=1'b0; 
	end
end

/*计算校验位理论值*/
always@(*)
begin
  if(!rst_n)
    bit_check=1'b0;
  else
    begin
	  case(check_mode)
	    3'd0 : bit_check=1'b1;   /*无校验位*/
	    3'd1 : bit_check=^data;  /*异或运算产生偶校验位*/
	    3'd2 : bit_check=^~data; /*同或运算产生奇校验位*/
		3'd3 : bit_check=1'b0;   /*固定0校验位*/
		3'd4 : bit_check=1'b1;   /*固定1校验位*/
		default:bit_check=1'b0;
	  endcase	  
	end
end
/************************************************************/
endmodule