`define WORD    [15:0]
`define WHIGH   [15:8]
`define WLOW    [7:0]
`define INST    [15:0]
`define STATE   [6:0]

`define REGSIZE [15:0]
`define MEMSIZE [65535:0]

`define OPLEN   [15]
`define SHORTOP [15:12]
`define LONGOP  [15:10]

`define IDEST   [7:4]
`define ILSRC   [3:0]
`define ILSRC_SIGN [3]
`define ILTYPE  [9:8]
`define ISSRCL  [3:0]
`define ISSRCH  [11:8]
`define ISSRC_SIGN [11]

// virtual op codes / state numbers
`define OPxhi  7'b1000000 // First 4 only have the low 4 bits as real op code
`define OPlhi  7'b1000001
`define OPxlo  7'b1000010
`define OPllo  7'b1000011 // The rest have the low 6 bits as real op code
`define OPadd  7'b1100000
`define OPsub  7'b1100001
`define OPxor  7'b1100010
`define OProl  7'b1100011
`define OPshr  7'b1100100
`define OPor   7'b1100101
`define OPand  7'b1100110
`define OPdup  7'b1100111
`define OPbz   7'b1101000 // same as... jz
`define OPbnz  7'b1101001 //  jnz
`define OPbn   7'b1101010 //  jn
`define OPbnn  7'b1101011 //  jnn
`define OPjerr 7'b1110000
`define OPfail 7'b1110001
`define OPex   7'b1110010
`define OPcom  7'b1110011
`define OPland 7'b1110100
`define OPsys  7'b1111111

`define STfetch 7'b0000000
`define STexec  7'b0000001
`define STtype  7'b0000010
`define STex1   7'b0000011
`define STex2   7'b0000100

`define ILTypeImm 2'b00
`define ILTypeReg 2'b01
`define ILTypeMem 2'b10
`define ILTypeUnd 2'b11

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
	$dumpfile;
	$dumpvars(0, PE);
	#10 reset = 1;
	#10 reset = 0;
	while (!halted) begin
		#10 clk = 1;
		#10 clk = 0;
	end
	$finish;
end
endmodule

module processor (halt, reset, clk);
output reg halt;
input reset, clk;
reg `WORD regfile `REGSIZE;
reg `WORD datamem `MEMSIZE;
reg `WORD instmem `MEMSIZE;
reg `WORD pc = 0;
reg `INST ir = 0;
reg `STATE st = 0;
reg `WORD src = 0;
reg `WORD t = 0;

integer j;

always @(reset) begin
	halt = 0;
	pc = 0;
	st = `STfetch;
	$readmemh0(regfile);
	$readmemh1(instmem);
	$readmemh2(datamem);
	for (j = 0; j < 16; j = j + 1) begin
		$dumpvars(0, regfile[j]);
	end
end

always @(posedge clk) begin
	case (st)
	`STfetch: begin
		ir <= instmem[pc];
		st <= `STexec;
	end
	`STexec: begin
		pc <= pc + 1;
		if (ir `OPLEN == 0) begin
			// All "short" instructions have an 8-bit src to load
			// Sign extend
			src <= {{8{ir `ISSRC_SIGN}}, ir `ISSRCH, ir `ISSRCL};
			st <= {3'b100, ir `SHORTOP};
		end else begin
			case ({1'b1, ir `LONGOP})
			// Instructions without src, just do directly
			`OPcom, `OPland, `OPsys: st <= {1'b1, ir `LONGOP};
			// Instructions with src, load src first
			default:                 st <= `STtype;
			endcase
		end
	end
	`STtype: begin
		case (ir `ILTYPE)
			`ILTypeImm: src <= {{12{ir `ILSRC_SIGN}}, ir `ILSRC}; // sign extend
			`ILTypeReg: src <= regfile[ir `ILSRC];
			`ILTypeMem: src <= datamem[regfile[ir `ILSRC]];
			`ILTypeUnd: halt <= 1; // Not implemented in this project
		endcase
		st <= {1'b1, ir `LONGOP};
	end

	`OPxhi: begin $display($time, ": XHI %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= {regfile[ir `IDEST]`WHIGH ^ src`WLOW, regfile[ir `IDEST]`WLOW}; st <= `STfetch; end
	`OPxlo: begin $display($time, ": XLO %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= {regfile[ir `IDEST]`WHIGH, regfile[ir `IDEST]`WLOW ^ src`WLOW}; st <= `STfetch; end
	`OPlhi: begin $display($time, ": LHI %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= {src `WLOW, 8'b0}; st <= `STfetch; end
	`OPllo: begin $display($time, ": LLO %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= src;               st <= `STfetch; end
	`OPadd: begin $display($time, ": ADD %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] + src;  st <= `STfetch; end
	`OPsub: begin $display($time, ": SUB %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] - src;  st <= `STfetch; end
	`OPxor: begin $display($time, ": XOR %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] ^ src;  st <= `STfetch; end
	`OProl: begin $display($time, ": ROL %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= ( (regfile[ir `IDEST] << src) | (regfile[ir `IDEST] >> (16-src)) ); st <= `STfetch; end
	`OPshr: begin $display($time, ": SHR %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] >> src; st <= `STfetch; end
	`OPor:  begin $display($time, ": OR  %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] | src;  st <= `STfetch; end
	`OPand: begin $display($time, ": AND %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= regfile[ir `IDEST] & src;  st <= `STfetch; end
	`OPdup: begin $display($time, ": DUP %d, %d", ir `IDEST, src); regfile[ir `IDEST] <= src;                     st <= `STfetch; end

`define DO_BRANCH pc <= ((ir `ILTYPE == `ILTypeImm) ? pc + src - 1 : src)

	`OPbz:  begin $display($time, ": BZ  %d, %d", ir `IDEST, src); if (regfile[ir `IDEST] == 0) `DO_BRANCH; st <= `STfetch; end
	`OPbnz: begin $display($time, ": BNZ %d, %d", ir `IDEST, src); if (regfile[ir `IDEST] != 0) `DO_BRANCH; st <= `STfetch; end
	`OPbn:  begin $display($time, ": BN  %d, %d", ir `IDEST, src); if ($signed(regfile[ir `IDEST]) < 0)  `DO_BRANCH; st <= `STfetch; end
	`OPbnn: begin $display($time, ": BNN %d, %d", ir `IDEST, src); if ($signed(regfile[ir `IDEST]) >= 0) `DO_BRANCH; st <= `STfetch; end

	`OPex:  begin $display($time, ": EX  %d, %d, %d, %d", ir `IDEST, src, regfile[ir `IDEST], regfile[ir `ILSRC]); t <= regfile[ir `IDEST];  st <= `STex1; end
	`STex1: begin regfile[ir `IDEST] <= src; st <= `STex2; end
	`STex2: begin datamem[regfile[ir `ILSRC]] <= t; st <=`STfetch; end

	// NOPs (not implemented in this project)
	`OPland: begin $display($time, ": LAND"); st <= `STfetch; end
	`OPjerr: begin $display($time, ": JERR"); st <= `STfetch; end
	`OPcom:  begin $display($time, ": COM");  st <= `STfetch; end

	// HALTs
	`OPfail: begin $display($time, ": FAIL");   halt <= 1; end // Not implemented in this project
	`OPsys:  begin $display($time, ": SYS");    halt <= 1; end
	default: begin $display($time, ": BAD OP"); halt <= 1; end
	endcase
end

// Simulation-only test to halt if src or ir are ever indeterminate
always @(src, ir) begin
	if ((| src) === 1'bx) begin
		$display($time, ": ERROR: src contains x's: %b", src);
		halt <= 1;
	end
	if ((| ir) === 1'bx) begin
		$display($time, ": ERROR: ir contains x's: %b", ir);
		halt <= 1;
	end
end
endmodule
