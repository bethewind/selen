// ----------------------------------------------------------------------------
// FILE NAME            	: core_csr.sv
// PROJECT                : Selen
// AUTHOR                 :	Alexandr Bolotnikov	
// AUTHOR'S EMAIL 				:	AlexsanrBolotnikov@gmail.com
// ----------------------------------------------------------------------------
// DESCRIPTION        		:	A description of instruction fetch station
// ----------------------------------------------------------------------------
`ifndef CORE_IF_S
`define CORE_IF_S
module core_if_s (
	input							clk,
	input							n_rst,
	//register control
	input 						if_kill,
	input 						if_enb,
	//from hazard control
	input 						if_mux_trn_s_in,
	// for transfer of address
	input[31:0]				if_addr_mux_trn_in,
	//for l1i $
	output[31:0]			if_addr_l1i_cash_out,
	output						if_val_l1i_cahe_out,
	//register if/dec
	output	reg[31:0]	if_pc_reg_out,	
	output 	reg[31:0]	if_pc_4_reg_out,
);

reg[31:0] 	pc;
wire[31:0] 	pc_adder;
wire[31:0] 	pc_next;
//program counter
always @(posedge clk, posedge (~n_rst))begin
	if(~n_rst) begin
		pc <= `PC_START;
	end
	else begin
		if(if_enb) begin
			pc <= pc_next;	
		end
		else begin
			 pc <= pc;
		end
	end
end
//adder and mux
assign pc_next= (if_mux_trn_s_in)?(if_addr_mux_trn_in):(pc_adder);
assign pc_adder = pc + 4;
assign if_addr_l1i_cash_out = pc;
assign if_val_l1i_cahe_out = 1'b1;
//register if/decode
always @(posedge clk, posedge (~n_rst)) begin
	if(~n_rst) begin
		if_pc_reg_out <= 0;
		if_pc_4_reg_out <= 0;
	end
	if(if_enb)begin
		if_pc_4_reg_out <= pc_adder;
		if_pc_reg_out <= pc;
	end
end
endmodule
`endif
