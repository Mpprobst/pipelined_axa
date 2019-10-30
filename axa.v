//This code is a reference from axa_alex.v, check that if confused on some parts

// Basic bit definitions
`define DATA		[15:0]
`define ADDRESS		[15:0]
`define SIZE		[65535:0]
`define INSTRUCTION	[15:0]
`define OP		[15:10]
`define OP8		[15:12]
`define OPPUSH		[14]
`define OP8IMM		[15]
`define SRCTYPE		[9:8]
`define DESTREG		[3:0]
`define SRCREG		[7:4]
`define SRCREGMSB 	[7]
`define SRC8		[11:4]
`define SRC8MSB 	[11]
`define STATE		[6:0]
`define REGS		[15:0]
`define OPERATION_BITS 	[6:0]
`define REGSIZE		[15:0]
`define USIZE [15:0]

//Op values
`define OPsys					6'b000000
`define OPcom					6'b000001
`define OPadd					6'b000010
`define OPsub					6'b000011
`define OPxor					6'b000100
`define OPex					6'b000101
`define OProl					6'b000110
`define OPbzjz					6'b001000
`define OPbnzjnz 				6'b001001
`define OPbnjn					6'b001010
`define OPbnnjnn 				6'b001011
`define OPjerr					6'b001110
`define OPfail					6'b001111
`define OPland					6'b010000
`define OPshr					6'b010001
`define OPor					6'b010010
`define OPand					6'b010011
`define OPdup					6'b010100
`define OPxhi					6'b100000
`define OPxlo					6'b101000
`define OPlhi					6'b110000
`define OPllo					6'b111000



// Checks
// 	8-bit
`define OPxhiCheck				4'b1000
`define OPxloCheck				4'b1010
`define OPlhiCheck				4'b1100
`define OPlloCheck				4'b1110

//	SrcType
`define SrcTypeRegister				2'b00
`define SrcTypeI4				2'b01
`define SrcTypeMem				2'b10

//State values
`define Start					7'b1000000
`define Decode					7'b1100000
`define Decode2 				7'b1100001
`define DecodeI8 				7'b1100010
`define Nop					    7'b1000010
`define SrcType					7'b1001000
`define SrcRegister				7'b1001001
`define SrcI4					7'b1001010
`define SrcI8 					7'b1001011
`define SrcMem					7'b1001100
`define OPex2					7'b1010000
`define OPex3					7'b1010001
`define Done					6'b111101
`define ALUOUT					7'b1010010
`define OPxhi2					7'b1011000
`define OPxhi3					7'b1011001



module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `DATA reglist `REGSIZE;  //register file
reg `DATA datamem `SIZE;  //data memory
reg `INSTRUCTION instrmem `SIZE;  //instruction memory
reg `DATA pc = 0;
reg `INSTRUCTION ir;
reg `STATE s;

reg `DATA usp;  //This is how we will index through undo buffer
reg `DATA u `USIZE;  //undo stack


always @(reset) begin
	halt <= 0;
	pc <= 0;
	s <= `Start;
//Setting initial values
    $readmemh0(reglist); //Registers
	$readmemh1(datamem); //Data
	$readmemh2(instrmem); //Instructions
end

//start pipeline


endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halt;

processor PE(halt, reset, clk);

initial begin
	$dumpfile;
	$dumpvars(0, PE);
	#10 reset = 1;
	#10 reset = 0;
	while (!halt) begin
		#10 clk = 1;
		#10 clk = 0;
	end
	$finish;
end
endmodule
