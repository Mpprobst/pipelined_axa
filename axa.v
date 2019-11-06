//This code is a reference from axa_alex.v, check that if confused on some parts

// Basic bit definitions
`define DATA		[15:0]
`define ADDRESS		[15:0]
`define SIZE		[65535:0]
`define WORD    	[15:0]
`define WHIGH   	[15:8]
`define WLOW		[7:0]
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
`define OPnop					6'b111100

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
`define SrcTypeI4Undo				2'b11

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
`define Done					6'b111101

`define NOP           16'b0


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `DATA reglist `REGSIZE;  //register file
reg `DATA datamem `SIZE;  //data memory
reg `INSTRUCTION instrmem `SIZE;  //instruction memory
reg `DATA pc,tpc;
reg `DATA passreg;   //This is the temp register to hold the source NOTE: src is used in stage 3, is this needed?
reg `INSTRUCTION ir0, ir1, ir2, ir3; //instruction registers for each stage 
reg jump;  //is jump or not
reg branch; //is branch or not
reg land;
reg `ADDRESS target;
reg wait1;    //check to make sure stage 2 is caught up
reg `STATE s, sLA;
reg `OP op4; // opcode for stage 4
reg `DATA des,des1, src,src1,src2, res;

reg `DATA usp;  //This is how we will index through undo buffer
reg `DATA u `USIZE;  //undo stack

always @(reset) begin
	halt = 0;
	pc = 0;
	usp=0;
	ir1= `NOP;
	ir2= `NOP;
	ir3= `NOP;
	op4 = `NOP;
	des = 0;
	src = 0;
	jump=0;
	branch=0;
	land=0;
	res = 0;
//Setting initial values
	$readmemh0(reglist); //Registers
	$readmemh1(datamem); //Data
	$readmemh2(instrmem); //Instructions
end

function setsdes;
	input `INSTRUCTION inst;
	setsdes = (((inst`OP >= `OPadd) && (inst `OP <= `OProl)) ||
				((inst`OP >= `OPshr) && (inst `OP <= `OPdup)) ||
				 (inst `OP == `OPxhi) ||
				 (inst `OP == `OPxlo) ||
				 (inst `OP == `OPlhi) ||
				 (inst `OP == `OPllo)
				);
endfunction
function usesdes;
	input `INSTRUCTION inst;
	usesdes = (((inst`OP >= `OPadd) && (inst `OP <= `OProl)) ||
				((inst`OP >= `OPshr) && (inst `OP <= `OPdup)) ||
				((inst`OP >= `OPbzjz) && (inst `OP <= `OPbnnjnn)) ||
				 (inst `OP == `OPxhi) ||
				 (inst `OP == `OPxlo) 
				);
endfunction

function usessrc;
	input `INSTRUCTION inst;
	usessrc = ((((inst`OP >= `OPadd) && (inst `OP <= `OProl)) ||
				((inst`OP >= `OPshr) && (inst `OP <= `OPdup))) && (inst `SRCTYPE == `SrcRegister));
endfunction

//start pipeline
assign pendpc = (setsdes(ir1) || setsdes(ir2) || setsdes(ir3));


//Stage1: Fetch
always @(posedge clk) begin
	if(jump) begin
		tpc= target;
		jump <=0;
	end else if(branch) begin
		tpc= pc + src-1;
		branch<=0;
	end else begin
		tpc=pc;
	end

	if(land) begin
		u[usp] =tpc;
		usp = usp+1;
		land =0;
		$display("UNDO buffer entry %d contains %d but should be %d.",usp,u[usp-1], ir1 `DESTREG);
	end


	if(wait1) begin
		pc<= tpc;
	end else begin
		if(pendpc) begin
			ir1 <= `NOP;
			pc <= tpc;
	end else begin
		ir0 = instrmem[tpc];
		ir1<= ir0;
		pc<= tpc+1;
	end
end


end //always block

//stage2: register read
always @(posedge clk) begin  
	if((ir1 != `NOP) && setsdes(ir2) && ((usesdes(ir1) && (ir1 `DESTREG == ir2 `DESTREG)) || (usessrc(ir1) && (ir1 `SRCREG == ir2 `DESTREG)))) begin 
		wait1 = 1;
		ir2 <= `NOP;
	end else begin
		wait1 = 0;
		des1 <= reglist[ir1 `DESTREG];
		if(ir1 `OP8IMM == 1'b0) begin
			case(ir1 `SRCTYPE)
				`SrcTypeRegister: begin src2 <= reglist[ir1 `SRCREG]; end
				`SrcTypeI4Undo: begin src2 <= ir1 `SRCREG; end
				`SrcTypeI4: begin src2 <= ir1 `SRCREG; end
				default: begin end
			endcase 
		end else begin 
			src2 <= ir1 `SRC8;
		end
		//$display("src: %d",src2);
		if(ir1`OPPUSH) begin
			//NEEDS TO PUSH des TO UNDO BUFFER
			u[usp] = ir1 `DESTREG;
			usp = usp+1;
			$display("UNDO buffer entry %d contains %d but should be %d.",usp,u[usp-1], ir1 `DESTREG);
		end
		ir2 <= ir1;
	end
end

//stage3: Data memory
always @(posedge clk) begin //should handle selection of source?
	if(ir2 == `NOP) begin
		ir3 <= `NOP;
	end else begin
		if(ir2 `SRCTYPE == `SrcTypeMem) begin
			src <= datamem[ir2 `SRCREG];
		end else begin
			src <=src2;
		end
		des<=des1;
		ir3 <= ir2;
	end
end

// stage4: execute and write
always @(posedge clk) begin
	if (ir3 == `NOP) begin
		jump <= 0;
	end else begin
		op4 = ir3 `OP;
                //des = ir3`DESTREG;
		//src <= src1;
		case(op4)
	
		`OPxlo: begin $display("xlo reg:%d src:%d", ir3`DESTREG, src); res = {des`WHIGH, src`WLOW ^ des`WLOW}; end
		`OPxhi: begin $display("xhi reg:%d src:%d", ir3`DESTREG, src); res = {src`WLOW ^ des`WHIGH  , des`WLOW}; end
		`OPllo: begin $display("llo reg:%d src:%d", ir3`DESTREG, src); res = {{8{src[7]}}, src}; op4 <=`OPnop; end
		`OPlhi: begin $display("lhi reg:%d src:%d", ir3`DESTREG, src); res = {src, 8'b0}; end
		`OPand: begin $display("and des:%d src:%d", des, src); res = des & src; end
		`OPor:	begin $display("or des:%d src:%d", des, src);  res = des | src; end
		`OPxor: begin $display("xor des:%d src:%d", des, src); res = des ^ src; end
		`OPadd: begin $display("add des:%d src:%d", des, src); res = des + src; end
		`OPsub: begin $display("sub des:%d src:%d", des, src); res = des - src; end
		`OProl: begin $display("rol des:%d src:%d", des, src); res <= { (des << src), (des >> (16 - src)) }; end
		`OPshr: begin $display("shr des:%d src:%d", des, src); res = des >> src; end
		`OPbzjz: begin if(des==0) begin 
			if(ir3 `SRCTYPE == 2'b01) begin
				branch<=1;
				$display("bz des:%d src:%d", des, src);
			end else begin
				jump<=1;
				target<= src;
				$display("jz reg:%d src:%d", ir3`DESTREG, src);
			end
			end
		end

		`OPbnzjnz: begin if(des!=0) begin
			if(ir3 `SRCTYPE == 2'b01) begin
				branch<=1;
				$display("bnz des:%d src:%d", des, src);
			end else begin
				jump<=1;
				target<=src;
				$display("jnz reg:%d src:%d", ir3`DESTREG, src);
			end
			end
		end

		`OPbnjn: begin if(des[15]==1) begin 
			if(ir3 `SRCTYPE == 2'b01) begin
				branch<=1;
				 $display("bn des:%d src:%d", des, src);
			end else begin
				jump<=1;
				target<=src;
				 $display("jn reg:%d src:%d", ir3`DESTREG, src);
			end
			end
		end

		`OPbnnjnn: begin if(des[15]==0) begin 
			if(ir3 `SRCTYPE == 2'b01) begin
				branch<=1;
				$display("bnn des:%d src:%d", des, src);
			end else begin
				jump<=1;
				target<=src;
				$display("jnn reg:%d src:%d", ir3`DESTREG, src);
			end
			end
		end

		`OPdup: begin $display("dup des:%d src:%d", des, src); res = src; op4 <= `OPnop; end
		`OPex: begin $display("ex reg:%d val: %d mem:%d val: %d", ir3`DESTREG, reglist[ir3`DESTREG], ir3 `SRCREG, src); 
			res <= src; datamem[reglist[ir3 `SRCREG]] <= des; op4 <= `OPnop; end
		`OPfail: begin if (!jump && !branch) begin // fail after a branch still gets executed. this prevents the fail in those cases
                        $display("FAIL");
			halt <= 1;
                        end
                        end
		`OPsys: begin if (!jump && !branch) begin // sys after a branch still gets executed. this prevents the fail in those cases
                        $display("sys call");
			halt <= 1;
                        end
                        end
                 default: begin
			$display("default case");
			halt <= 1;
                end
		endcase	


		if(setsdes(ir3) && !jump && !branch) begin // check if we are ready to set the des 
			reglist[ir3 `DESTREG] = res;
			jump <= 0;
			$display("res: %d", res);
		end 
	end
end //  always
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
