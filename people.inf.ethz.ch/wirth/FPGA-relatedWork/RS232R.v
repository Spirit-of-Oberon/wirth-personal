`timescale 1ns / 1ps  // NW 4.5.09 / 15.8.10 / 15.11.10

// RS232 receiver for 19200 bps, 8 bit data
// clock is 25 MHz; 25000 / 1302 = 19.2 KHz
// clock is 35 MHz; 35000 / 1823 = 19.2 KHz

module RS232R(
    input clk, rst,
    input done,   // "byte has been read"
    input RxD,
    output rdy,
    output [7:0] data);

wire endtick, midtick;
reg run, stat;
reg [11:0] tick;
reg [3:0] bitcnt;
reg [7:0] shreg;

assign endtick = tick == 1302;
assign midtick = tick == 651;
assign endbit = bitcnt == 8;
assign data = shreg;
assign rdy = stat;

always @ (posedge clk) begin
  run <= (~RxD) ? 1 : (~rst | endtick & endbit) ? 0 : run;
  tick <= (run & ~endtick) ? tick + 1 : 0;
  bitcnt <= (endtick & ~endbit) ? bitcnt + 1 :
    (endtick & endbit) ? 0 : bitcnt;
  shreg <= midtick ? {RxD, shreg[7:1]} : shreg;
  stat <= (endtick & endbit) ? 1 : (~rst | done) ? 0 : stat;
end	 
endmodule
