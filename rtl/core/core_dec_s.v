// ----------------------------------------------------------------------------
// FILE NAME            	: core_csr.sv
// PROJECT                : Selen
// AUTHOR                 :	Alexandr Bolotnikov	
// AUTHOR'S EMAIL 				:	AlexsanrBolotnikov@gmail.com
// ----------------------------------------------------------------------------
// DESCRIPTION        		:	A description of decode station
// ----------------------------------------------------------------------------
//include core_defines.vh;
//include opcodes.vh;
module core_dec_s(
	input 						dec_start_in,
	input							clk,
	input							rst_n,
	input 						dec_enb,
	input							dec_kill,
	//from if
	input[31:0]				dec_inst_in,
	input							dec_l1i_ack_in,
	//from wb
	input							dec_we_reg_file_in,
	input[4:0]				dec_rd_reg_file_in,
	input[31:0]				dec_data_wrt_in,
	//input form if station
	input[31:0]				dec_pc_in,
	input[31:0]				dec_pc_4_in,
	// 2 exe station
	//control pins
	output reg[2:0]		dec_wb_sx_op_out_reg,
	output reg[5:0]		dec_mux_bus_out_reg,
	output reg 				dec_we_reg_file_out_reg,		
	output reg[3:0]		dec_alu_op_out_reg,	
	output reg[2:0] 	dec_alu_cnd_out_reg,
	//cahs
	output reg 				dec_l1d_req_val_out_reg,
	output reg 			 	dec_l1d_req_cop_out_reg,
	output reg[2:0]		dec_l1d_req_size_out_reg,
	//	information pins
	output reg[31:0]	dec_src1_out_reg,
	output reg[31:0]	dec_src2_out_reg,
	output reg[31:0]	dec_sx_imm_out_reg,
	output reg[31:0]	dec_pc_out_reg,
	output reg[31:0]	dec_pc_4_out_reg,
	//
	output reg[4:0]		dec_rs1_out_reg,
	output reg[4:0]		dec_rs2_out_reg,
	output reg[4:0]		dec_rd_out_reg,
	// for hazard 
	output reg[1:0]		dec_hazard_cmd_out_reg,
	output[1:0]				dec2haz_cmd_out,
	output						dec_stall_out,

	//validation of instruction 
	output reg 			dec_val_inst_out_reg
);
wire[2:0] 	ctrl2dec_wb_sx_op;
wire 				ctrl2dec_l1d_val;
wire[2:0] 	ctrl2dec_l1d_size;
wire 				ctrl2dec_l1d_cop_lsb;
wire[5:0] 	ctrl2dec_mux_bus;
wire[3:0] 	ctrl2dec_alu_op;
wire[2:0] 	ctrl2dec_alu_cnd;
wire 				ctrl2dec_we_reg_file;
wire 				ctrl2dec_order_reg_file;
wire[2:0] 	ctrl2dec_dec_sx_op_out;
wire[31:0] 	reg_file2dec_src1;
wire[31:0]	reg_file2dec_src2;
wire[1:0] 	ctrl2dec_haz_cmd;
core_reg_file reg_file(
.clk(clk),
.rst_n(rst_n),
.rs1_in(dec_inst_in[19:15]),
.rs2_in(dec_inst_in[24:20]),
.rd_in(dec_rd_reg_file_in),
.data_in(dec_data_wrt_in),
.we_in(dec_we_reg_file_in),
.order_in(ctrl2dec_order_reg_file),
.src1_out(reg_file2dec_src1),
.src2_out(reg_file2dec_src2)
);
core_cpu_ctrl cpu_ctrl(
.ctrl_inst_in(dec_inst_in),
//to reg 
.ctrl_wb_sx_op_out(ctrl2dec_wb_sx_op),
.ctrl_mux_bus_out(ctrl2dec_mux_bus),
.ctrl_alu_op_out(ctrl2dec_alu_op),
.ctrl_alu_cnd_out(ctrl2dec_alu_cnd),
.ctrl_we_reg_file_out(ctrl2dec_we_reg_file),
.ctrl_l1d_size_out(ctrl2dec_l1d_size),
.ctrl_l1d_cop_lsb_out(ctrl2dec_l1d_cop_lsb),
.ctrl_l1d_val_out(ctrl2dec_l1d_val), 				
//inner for decode phase 
.ctrl_order_reg_file_out(ctrl2dec_order_reg_file),
.ctrl_dec_sx_op_out(ctrl2dec_dec_sx_op_out),
.ctrl_haz_cmd_out(ctrl2dec_haz_cmd)
);
//sx_imm
reg[31:0] sx_imm_loc;
always @* begin
	case(ctrl2dec_dec_sx_op_out) 
		`SX_AUIPC_LUI: sx_imm_loc = $signed(dec_inst_in[31:12]);
		`SX_LD_I_R_JALR: sx_imm_loc = $signed(dec_inst_in[31:20]);
		`SX_SB:sx_imm_loc = $signed({dec_inst_in[31],dec_inst_in[7],dec_inst_in[30:25],dec_inst_in[11:8]});
		`SX_UJ_JAL:sx_imm_loc = $signed({dec_inst_in[31],dec_inst_in[19:12],dec_inst_in[20],dec_inst_in[30:21]});
		`SX_ST:sx_imm_loc = $signed({dec_inst_in[31:25],dec_inst_in[4:0]});
	endcase
end

always @(negedge clk,negedge rst_n) begin
	dec_val_inst_out_reg <= 1'b0;
	if(dec_enb) begin
		dec_pc_out_reg <= dec_pc_in;
		dec_pc_4_out_reg <= dec_pc_4_in;
		dec_wb_sx_op_out_reg <= ctrl2dec_wb_sx_op;
		dec_l1d_req_val_out_reg <= ctrl2dec_l1d_val;
		dec_l1d_req_cop_out_reg <= ctrl2dec_l1d_cop_lsb;
		dec_l1d_req_size_out_reg <= ctrl2dec_l1d_size;
		dec_mux_bus_out_reg <= ctrl2dec_mux_bus;
		dec_alu_op_out_reg <= ctrl2dec_alu_op;
		dec_alu_cnd_out_reg <= ctrl2dec_alu_cnd;
		dec_we_reg_file_out_reg <= ctrl2dec_we_reg_file;
		dec_rs1_out_reg <= dec_inst_in[19:15];
		dec_rs2_out_reg <= dec_inst_in[24:20]; 
		dec_rd_out_reg <= dec_inst_in[11:7];
		dec_src1_out_reg <= reg_file2dec_src1;
		dec_src2_out_reg <= reg_file2dec_src2;
		dec_hazard_cmd_out_reg <= ctrl2dec_haz_cmd;
		dec_val_inst_out_reg <= dec_l1i_ack_in;
		dec_sx_imm_out_reg <= sx_imm_loc;
	end
	if(dec_kill|(~rst_n)) begin
		dec_we_reg_file_out_reg<= 1'b0;
		dec_l1d_req_val_out_reg <= 1'b0;
		dec_hazard_cmd_out_reg <= `HZRD_OTHER;
	end
end
reg start;
reg stall_loc;
always @(posedge clk) begin
	if(~rst_n) start <= 1'b0;
	else begin
		start <= 1'b1;
	end
end
always @* begin
	if(start) stall_loc = ~dec_l1i_ack_in;
	else stall_loc  =1'b0;
end
assign  dec2haz_cmd_out = ctrl2dec_haz_cmd;
assign dec_stall_out = stall_loc;
endmodule
/*
reg stall_loc;
always @(posedge clk, posedge dec_l1i_ack_in,negedge rst_n) begin
	if(~rst_n) stall_loc <= 1'b0;
	else begin
		stall_loc <= ~ dec_l1i_ack_in;
	end
end
assign dec_stall_out = stall_loc;
if(dec_kill) begin
		dec_wb_sx_op_out_reg <= 0;
		dec_l1d_req_val_out_reg <= 0;
		dec_l1d_req_cop_out_reg <= 0;
		dec_l1d_req_size_out_reg <= 0;
		dec_mux_bus_out_reg <= 0;
		dec_alu_op_out_reg <= 0;
		dec_alu_cnd_out_reg <= 0;
		dec_we_reg_file_out_reg <= 0;
		dec_rs1_out_reg <= 0;
		dec_rs2_out_reg <= 0; 
		dec_rd_out_reg <= 0;
		dec_hazard_cmd_out_reg <=0;
		dec_val_inst_out_reg <=0;
	end*/