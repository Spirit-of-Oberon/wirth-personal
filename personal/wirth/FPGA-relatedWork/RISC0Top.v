`timescale 1ns / 1ps  // NW 27.5.09  LL 10.12.09  NW 28.7.2011

module RISC0Top(
  input CLK50M,
  input rstIn,
  input RxD,
  input [7:0] swi,
  output TxD,
  output [7:0] leds);
	 
wire clk, clk50;
reg rst, clk25;

wire[5:0] ioadr;
wire [3:0] iowadr;
wire iowr;
wire[31:0] inbus, outbus;

wire [7:0] dataTx, dataRx;
wire rdyRx, doneRx, startTx, rdyTx;
wire limit;  // of cnt0

reg [7:0] Lreg;
reg [15:0] cnt0;
reg [31:0] cnt1; // milliseconds

RISC0 riscx(.clk(clk), .rst(rst), .iord(iord), .iowr(iowr),
   .ioadr(ioadr), .inbus(inbus), .outbus(outbus));
			
RS232R receiver(.clk(clk), .rst(rst), .RxD(RxD), .done(doneRx), .data(dataRx), .rdy(rdyRx));
RS232T transmitter(.clk(clk), .rst(rst), .start(startTx), .data(dataTx), .TxD(TxD), .rdy(rdyTx));

assign iowadr = ioadr[5:2];
assign inbus = (iowadr == 0) ? cnt1 :
    (iowadr == 1) ? swi :
    (iowadr == 2) ? {24'b0, dataRx} :
    (iowadr == 3) ? {30'b0, rdyTx, rdyRx} : 0;
    
assign dataTx = outbus[7:0];
assign startTx = iowr & (iowadr == 2);
assign doneRx = iord & (iowadr == 2);
assign limit = (cnt0 == 25000);
assign leds = Lreg;

always @(posedge clk) 
begin
  rst <= ~rstIn;
  Lreg <= ~rst ? 0 : (iowr & (iowadr == 1)) ? outbus[7:0] : Lreg;
  cnt0 <= limit ? 0 : cnt0 + 1;
  cnt1 <= limit ? cnt1 + 1 : cnt1;
end

//The Clocks
IBUFG clkInBuf(.I(CLK50M), .O(clk50));
always @ (posedge clk50) clk25 <= ~clk25;
BUFG clk150buf(.I(clk25), .O(clk));
endmodule
