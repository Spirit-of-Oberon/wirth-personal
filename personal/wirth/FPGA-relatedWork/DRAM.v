`timescale 1ns / 1ps
module DRAM(input [10:0] adr,
    input [31:0] din,
    output reg [31:0] dout,
    input we,
    input clk);
reg [31:0] mem [2047: 0];
always @(posedge clk) begin
    if (we) mem[adr] <= din;
	 dout <= mem[adr];
end	 
endmodule

