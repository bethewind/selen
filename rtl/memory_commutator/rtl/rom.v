// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------
// FILE NAME      : rom.v
// PROJECT        : Selen
// AUTHOR         : Sokolovskii Artem
// AUTHOR'S EMAIL : 
// ----------------------------------------------------------------------------
// DESCRIPTION    : 
// ----------------------------------------------------------------------------

module rom(
	input sys_clk,
	input sys_rst,
	
	// RAM 
	input    				rom_stb_i,
	output 		 			rom_ack_o,
	input	 [31:0]			rom_addr_i,
	output 	 [31:0] 		rom_data_o
);
	reg 	 [31:0] 		data_o;
	reg 	 [31:0] 		rom [0:6];
	reg 					rom_ack_r;

	always @(posedge sys_clk, posedge sys_rst) begin	
		if (sys_rst) begin
			rom[0] <= 32'hFFFFFFFF;
			rom[1] <= 32'hFFFFFFFF;
			rom[2] <= 32'hFFFFFFFF;
			rom[3] <= 32'hFFFFFFFF;
			rom[4] <= 32'hFFFFFFFF;
			rom[5] <= 32'hFFFFFFFF;
			rom[6] <= 32'hFFFFFFFF;
			
			rom_ack_r <= 1'b0;
		end else begin
			data_o <= rom[rom_addr_i];
			rom_ack_r <= rom_stb_i;
		end
	end

	assign rom_data_o = data_o;
	assign rom_ack_o  = rom_ack_r;
endmodule
