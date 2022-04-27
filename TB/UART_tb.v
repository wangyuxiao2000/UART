/*************************************************************/
//function: UART测试模块
//Author  : WangYuxiao
//Email   : wangyuxiao2000@bupt.edu.cn
//Data    : 2022.4.27
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ps       /*定义 仿真时间单位/精度*/
`define Period 20            /*定义 时钟周期*/

module UART_tb ();
/**************************信号定义**************************/
reg clk; 
reg rst_n;
wire tx;  
wire data_in_ready;  
wire [7:0] data_out;
wire data_out_valid;
wire check_flag;
wire tx_clk;
assign tx_clk=i1.tx_clk;  
wire rx_clk;
assign rx_clk=i1.rx_clk;  
/************************************************************/



/************************工作参数设置************************/
parameter system_clk=50_000000;    /*定义系统时钟频率*/
parameter band_rate=9600;          /*定义波特率*/
parameter data_bits=8;             /*定义数据位数,在5-8取值*/
parameter check_mode=1;            /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
parameter stop_mode=0;             /*定义停止位类型——stop_mode=0——1位停止位,stop_mode=1——1.5位停止位,stop_mode=2——2位停止位*/
/************************************************************/



/************************例化待测模块************************/
UART #(.system_clk(system_clk), 
       .band_rate(band_rate),   
	   .data_bits(data_bits),   
	   .check_mode(check_mode), 
	   .stop_mode(stop_mode)    
	   ) i1(.clk(clk),
			.rst_n(rst_n),
			.tx_en(1'b1),
			.data_in(8'b0011_1011),
			.data_in_valid(1'b1),
			.data_in_ready(data_in_ready),
			.tx(tx),
			.rx_en(1'b1),
			.rx(tx),
			.data_out(data_out),
			.data_out_valid(data_out_valid),
			.check_flag(check_flag)
			);
/************************************************************/



/*********************产生时钟及复位信号*********************/
initial 
begin
  clk=0;
  forever
    #(`Period/2) clk=~clk;  	
end
initial 
begin
  rst_n=0;
  #(`Period*10.75) rst_n=1; 	
end
/************************************************************/

endmodule