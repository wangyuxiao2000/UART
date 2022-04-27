/*************************************************************/
//function: UART数据发送模块
//Author  : WangYuxiao
//Email   : wangyuxiao2000@bupt.edu.cn
//Data    : 2022.4.27
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ps

module uart_tx (clk,rst_n,tx_en,tx_clk,data_in,data_in_valid,data_in_ready,tx,tx_clk_en);
input clk;                         /*系统时钟*/
input rst_n;                       /*低电平异步复位信号*/
input tx_en;                       /*发送模块使能信号,高电平有效*/
input tx_clk;                      /*发送模块波特率时钟*/
input [7:0] data_in;               /*待发送数据*/
input data_in_valid;               /*待发送数据有效标志,高电平有效*/
output data_in_ready;              /*当前有数据进行UART发送时,将data_in_ready拉低,当前无数据进行UART发送时,将data_in_ready拉高;data_in_ready=1时,允许信源向UART发送模块传输新的待发送数据*/
output reg tx;                     /*FPGA端UART发送口*/
output reg tx_clk_en;              /*发送模块波特率时钟使能信号,高电平有效*/

/************************工作参数设置************************/
parameter system_clk=50_000000;    /*定义系统时钟频率*/
parameter band_rate=9600;          /*定义波特率*/
parameter data_bits=8;             /*定义数据位数,在5-8取值*/
parameter check_mode=1;            /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
parameter stop_mode=0;             /*定义停止位类型——stop_mode=0——1位停止位,stop_mode=1——1.5位停止位,stop_mode=2——2位停止位*/
localparam N=system_clk/band_rate; /*计算每bit持续的时钟数*/
/************************************************************/



/***********************锁存data_in数据**********************/
reg [data_bits-1:0] data;
reg tx_ready; /*当前有数据进行UART发送时,tx_ready=0;当前无数据进行UART发送时,tx_ready=1*/

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    data<=0;
  else if(tx_ready)/*当前无数据进行UART发送时,允许接收信源传来的新数据*/
    begin
	  if(data_in_valid)
	    data<=data_in[data_bits-1:0];
	  else
	    data<=data;
	end
  else/*进行UART发送的过程中,数据保持锁存*/
    data<=data;
end
/************************************************************/



/*************************计算校验位*************************/
reg bit_check; /*校验位*/

always@(*)
begin
  if(!rst_n)
    bit_check=1'b0;
  else
    begin
	  case(check_mode)
	    3'd0 : bit_check=1'b0;   /*无校验位*/
	    3'd1 : bit_check=^data;  /*异或运算产生偶校验位*/
	    3'd2 : bit_check=^~data; /*同或运算产生奇校验位*/
		3'd3 : bit_check=1'b0;   /*固定0校验位*/
		3'd4 : bit_check=1'b1;   /*固定1校验位*/
		default:bit_check=1'b0;
	  endcase
	end
end
/************************************************************/



/*************************计算停止位*************************/
reg [$clog2(2*N-1):0] stop_time;

always@(*)
begin
  if(!rst_n)
    stop_time=0;
  else
    begin
	  case(stop_mode)
	    2'd0 : stop_time=N-1;      /*1位停止位*/
	    2'd1 : stop_time=3*N/2-1;  /*1.5位停止位*/
	    2'd2 : stop_time=2*N-1;    /*2位停止位*/
		default:stop_time=0;
	  endcase
	end
end
/************************************************************/



/*************************进行TX发送*************************/
reg [5:0] tx_state; /*UART发送状态机*/
reg [2:0] data_cnt;
reg [$clog2(2*N-1):0] stop_cnt;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
	  tx_state<=6'b000001;
	  tx_ready<=1'b1;
	  tx_clk_en<=1'b0;
	  stop_cnt<=0;
	  data_cnt<=0;
	  tx<=1'b1;  
    end
  else if(tx_en)
    begin
      case(tx_state)
	    6'b000001 : begin/*等待有效数据输入*/
		              if(data_in_valid)
				        begin
	                      tx_state<=6'b000010;
	                      tx_ready<=1'b0;
	                      tx_clk_en<=1'b1;
                          stop_cnt<=0;	
                          data_cnt<=0;					 
                          tx<=1'b1;					 
				        end
				      else
				        begin
	                      tx_state<=6'b000001;
	                      tx_ready<=1'b1;
	                      tx_clk_en<=1'b0;
				  	      stop_cnt<=0;
				  	      data_cnt<=0;
				          tx<=1'b1;
				        end
		            end
		6'b000010 : begin/*发送起始位*/
		              if(tx_clk)
				        begin
				          tx_state<=6'b000100;
				      	  tx_ready<=1'b0;
				      	  tx_clk_en<=1'b1;
				      	  stop_cnt<=0;
				      	  data_cnt<=0;
				      	  tx<=1'b0;
				        end
				      else
				        begin
				          tx_state<=tx_state;
				      	  tx_ready<=tx_ready;
				      	  tx_clk_en<=tx_clk_en;
				      	  stop_cnt<=0;
				      	  data_cnt<=data_cnt;
				      	  tx<=tx;
				        end
		            end
		6'b000100 : begin/*发送数据位(按从LSB到MSB的顺序发送)*/
		              if(tx_clk)
				        begin
				     	  tx_ready<=1'b0;
				     	  tx_clk_en<=1'b1;
				     	  stop_cnt<=0;
				     	  if(data_cnt==data_bits-1)
				     	    begin
				     	  	  data_cnt<=3'd0;
				     	      tx<=data[data_cnt];
				     	  	  if(check_mode==3'd0)
				     	  	    tx_state<=6'b010000;
				     	  	  else
				     	  	    tx_state<=6'b001000;
				     	    end
				     	  else
				     	    begin 
				     	  	  data_cnt<=data_cnt+3'd1;
				     	      tx<=data[data_cnt];
                              tx_state<=6'b000100;					     
				     	    end
				        end
				      else
				        begin
				          tx_state<=tx_state;
				      	  tx_ready<=tx_ready;
				      	  tx_clk_en<=tx_clk_en;
				      	  stop_cnt<=0;
				      	  data_cnt<=data_cnt;
				      	  tx<=tx;
				        end
		            end			   
		6'b001000 : begin/*发送校验位*/
		              if(tx_clk)
				        begin
				          tx_state<=6'b010000;
				      	  tx_ready<=1'b0;
				      	  tx_clk_en<=1'b1;
				      	  stop_cnt<=0;
				      	  data_cnt<=0;
				      	  tx<=bit_check;					   
				        end
				      else
				        begin
				          tx_state<=tx_state;
				      	  tx_ready<=tx_ready;
				      	  tx_clk_en<=tx_clk_en;
				      	  stop_cnt<=0;
				      	  data_cnt<=data_cnt;
				      	  tx<=tx;
				        end
		            end
		6'b010000 : begin/*发送停止位*/
		              if(tx_clk)
				        begin
				          tx_state<=6'b100000;
				      	  tx_ready<=1'b0;
				      	  tx_clk_en<=1'b1;
				      	  stop_cnt<=0;
				      	  data_cnt<=0;
                          tx<=1'b1;
				        end
				      else
				        begin
				          tx_state<=tx_state;
				      	  tx_ready<=tx_ready;
				      	  tx_clk_en<=tx_clk_en;
				      	  stop_cnt<=0;
				      	  data_cnt<=data_cnt;
				      	  tx<=tx;
				        end		         
		            end		
		6'b100000 : begin
	                  if(stop_cnt==stop_time)
				        begin
				          tx_state<=6'b000001;
				      	  tx_ready<=1'b1;
				      	  tx_clk_en<=1'b0;
				      	  stop_cnt<=0;
				      	  data_cnt<=0;
                          tx<=1'b1;
				        end
				      else
				        begin
				          tx_state<=6'b100000;
				      	  tx_ready<=1'b0;
				      	  tx_clk_en<=1'b1;
				      	  stop_cnt<=stop_cnt+1;
				      	  data_cnt<=data_cnt;
                          tx<=1'b1;
				        end
		            end			   
	    default:begin
	              tx_state<=6'b000001;
	              tx_ready<=1'b1;
	              tx_clk_en<=1'b0;
				  stop_cnt<=0;
				  data_cnt<=0;
	              tx<=1'b1;		
		        end
	  endcase
    end	
  else
    begin
	  tx_state<=6'b000001;
	  tx_ready<=1'b1;
	  tx_clk_en<=1'b0;
	  stop_cnt<=0;
	  data_cnt<=0;
	  tx<=1'b1;  
	end
end

assign data_in_ready=tx_ready;
/************************************************************/

endmodule