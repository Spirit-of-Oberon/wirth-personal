`timescale 1ns / 1ps  // NW 3.12.2010

module Multiplier(
  input clk, run, u,
  output stall,
  input [31:0] x, y,
  output [63:0] z);

reg [4:0] S;    // state
reg [31:0] B2, A2;  // high and low parts of partial product
wire [32:0] B0, B00, B01;
wire [31:0] B1, A0, A1;

assign stall = run & ~(S == 31);
assign B00 = (S == 0) ? 0 : {B2[31] & u, B2};
assign B01 = A0[0] ? {y[31] & u, y} : 0;
assign B0 = ((S == 31) & u) ? B00 - B01 : B00 + B01;
assign B1 = B0[32:1];
assign A0 = (S == 0) ? x : A2;
assign A1 = {B0[0], A0[31:1]};
assign z = {B1, A1};

always @ (posedge(clk)) begin
  B2 <= B1; A2 <= A1;
  S <= run ? S+1 : 0;
end

endmodule
