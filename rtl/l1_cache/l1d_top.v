// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// FILE NAME      : l1d_top.v
// PROJECT        : Selen
// AUTHOR         : Grigoriy Zhiharev
// AUTHOR'S EMAIL : gregory.zhiharev@gmail.com
// ----------------------------------------------------------------------------
// DESCRIPTION    : write-through, no-write-allocate
//
// 1.0 		23.01.16  	Начальная версия со статической памятью
// 1.1    30.03.16    Исправлена отработка записей. Получается
//                    большая задержка, 3 такта
// 1.2    31.03.16    Улучшена обработка записей, задержка 1 такт
// 1.3    03.04.16    Исправлены ошибки связанные с отработкой записей и
//                    некэшруемых зпросов. Исправлена логи для отработки
//                    конвейерных запросов
// 1.4    22.04.16    Переработана структура конвейера
// ----------------------------------------------------------------------------
`ifndef INC_L1D_TOP
`define INC_L1D_TOP

module l1d_top
(
	input 															clk,
	input 															rst_n,
	input 															core_req_val,
	input 		 [`CORE_ADDR_WIDTH-1:0] 	core_req_addr,
	input 		 [`CORE_COP_WIDTH-1:0]   	core_req_cop,
	input 		 [`CORE_DATA_WIDTH-1:0] 	core_req_wdata,
	input 	 	 [`CORE_SIZE_WIDTH-1:0]  	core_req_size,
	output                        			core_req_ack,
	output reg [`CORE_DATA_WIDTH-1:0] 	core_ack_data,
	output	 														mau_req_val,
	output                         			mau_req_nc,
	output                       				mau_req_we,
	output 	   [`CORE_ADDR_WIDTH-1:0]		mau_req_addr,
	output     [`CORE_DATA_WIDTH-1:0] 	mau_req_wdata,
	output reg [`CORE_BE_WIDTH-1:0]     mau_req_be,
	input 															mau_req_ack,
	input                               mau_ack_nc,
	input                               mau_ack_we,
	input 		 [`L1_LINE_SIZE-1:0] 			mau_ack_data
);

  // ------------------------------------------------------
  // FUNCTION: one_hot_num
  // ------------------------------------------------------
  function [$clog2(`L1_WAY_NUM)-1:0] one_hot_num;
    input [`L1_WAY_NUM-1:0] one_hot_vector;
    integer i,j;
    reg [`L1_WAY_NUM-1:0] tmp;
    for(i = 0; i < $clog2(`L1_WAY_NUM); i=i+1) begin
      for(j = 0; j < `L1_WAY_NUM; j=j+1) begin
        tmp[j] = one_hot_vector[j] & j[i];
      end
      one_hot_num[i] = |tmp;
    end
  endfunction

  wire 														cache_ready;

	wire                          	s0_req_val;
	wire [`CORE_TAG_WIDTH-1:0] 			s0_req_tag;
	wire [`CORE_IDX_WIDTH-1:0] 			s0_req_idx;
	wire [`CORE_OFFSET_WIDTH-1:0] 	s0_req_offset;
  reg  [`L1_LINE_SIZE/8-1:0]      s0_req_be;
	wire 														s0_req_nc;
	wire 														s0_req_wr;
	wire 														s0_req_rd;

  reg 											 			del_buf_val_r;
  reg [`CORE_ADDR_WIDTH-1:0] 			del_buf_addr_r;
  reg [`CORE_DATA_WIDTH-1:0] 			del_buf_data_r;
  reg                             del_buf_hit_r;
  reg [`L1_LINE_SIZE/8-1:0]       del_buf_be_r;
  reg [`L1_WAY_NUM-1:0]           del_buf_way_vect_r;
  reg                             del_buf_way_val_r;
	wire [`CORE_TAG_WIDTH-1:0] 			del_buf_tag;
	wire [`CORE_IDX_WIDTH-1:0] 			del_buf_idx;
	wire [`CORE_OFFSET_WIDTH-1:0] 	del_buf_offset;
	wire                            del_buf_clean;
	wire                            del_buf_dm_access;

	reg                           	s1_req_val_r;
  reg  [`CORE_ADDR_WIDTH-1:0]     s1_req_addr_r;
	reg  [`CORE_TAG_WIDTH-1:0] 			s1_req_tag_r;
	reg  [`CORE_IDX_WIDTH-1:0] 			s1_req_idx_r;
	reg  [`CORE_OFFSET_WIDTH-1:0] 	s1_req_offset_r;
	reg  [`CORE_DATA_WIDTH-1:0] 		s1_req_wdata_r;
	reg  [`CORE_SIZE_WIDTH-1:0]  		s1_req_size_r;
	reg                             s1_req_we_r;
	reg                             s1_req_nc_r;

	wire  [`CORE_OFFSET_WIDTH-1:0] 	s1_alligned_offset;

	wire                           	stall;

	reg  [`L1_WAY_NUM-1:0] 					tag_cmp_vect;
	wire                            req_ack;
	wire                            req_we_ack;
	wire [`L1_LINE_SIZE-1:0]        core_line_data;

	reg 														mau_req_ack_r;
	reg  [`L1_LINE_SIZE-1:0]        mau_ack_data_r;
	reg      												mau_ack_nc_r;

	wire [`L1_WAY_NUM-1:0]					ld_ready_vect;
	wire [`L1_WAY_NUM-1:0]          ld_ren_vect;
	wire [`CORE_IDX_WIDTH-1:0]      ld_raddr;
	wire [`CORE_IDX_WIDTH-1:0]      ld_waddr;
	wire [`L1_LD_MEM_WIDTH-1:0] 		ld_rdata 		[0:`L1_WAY_NUM-1];
	wire [`L1_WAY_NUM-1:0] 					ld_rd_val_vect;
	wire [`CORE_TAG_WIDTH-1:0] 			ld_rd_tag   [0:`L1_WAY_NUM-1];
	wire [`L1_WAY_NUM-1:0]          ld_wen_vect;
	wire [`L1_LD_MEM_WIDTH-1:0] 		ld_wdata;
	wire  													ld_wr_val;
	wire [`CORE_TAG_WIDTH-1:0] 			ld_wr_tag;

	wire                            lru_req;
	wire                            lru_ready;
	wire [`L1_WAY_NUM-1:0] 					lru_way_vect;
	reg  [`L1_WAY_NUM-1:0] 					lru_way_vect_r;
	wire 														lru_hit;
	wire                            lru_evict_val;
	wire [$clog2(`L1_WAY_NUM)-1:0]  lru_way_pos;

	reg  [`L1_WAY_NUM-1:0]          dm_en_vect;
	reg  [`L1_WAY_NUM-1:0]          dm_we_vect;
	reg  [`CORE_IDX_WIDTH-1:0]      dm_addr;
	reg  [`L1_LINE_SIZE-1:0]        dm_rdata [0:`L1_WAY_NUM-1];
	reg  [`L1_LINE_SIZE-1:0] 				dm_wdata;
	wire [`L1_LINE_SIZE/8-1:0]      dm_wr_be;

	wire s1_en;

	// -----------------------------------------------------
	// S0
	// -----------------------------------------------------

	assign cache_ready = &ld_ready_vect & lru_ready;

	assign s0_req_val = core_req_val & ~stall;
	assign s0_req_nc = (core_req_cop == `CORE_REQ_RDNC) | (core_req_cop == `CORE_REQ_WRNC);
	assign s0_req_wr = (core_req_cop == `CORE_REQ_WR);
	assign s0_req_rd = (core_req_cop == `CORE_REQ_RD);

	assign {s0_req_tag, s0_req_idx, s0_req_offset} = core_req_addr;

	always @* begin
		if     (core_req_size == 1) s0_req_be = 4'b0001 << s0_req_offset;
		else if(core_req_size == 2) s0_req_be = 4'b0011 << s0_req_offset;
		else                        s0_req_be = 4'b1111 << s0_req_offset;
	end

  // -----------------------------------------------------
	// DELAYED BUFFER
	// DEBUG
	// -----------------------------------------------------

	assign del_buf_clean = (~mau_req_ack | mau_ack_nc) &
	                       (~core_req_val | (core_req_val & s0_req_nc));

	assign del_buf_dm_access = (core_req_val & s0_req_wr) |
														 (core_req_val & s0_req_nc) |
														 ~core_req_val;

	always @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			del_buf_val_r <= 1'b0;
			del_buf_hit_r <= 1'b0;
		end else begin
			del_buf_val_r <= (core_req_val & s0_req_wr) | (~del_buf_clean & del_buf_val_r);
			del_buf_hit_r <= del_buf_val_r & s0_req_val & s0_req_rd & (del_buf_addr_r == core_req_addr);
		end
	end

	always @(posedge clk) begin
		if(s0_req_val & s0_req_wr) begin
				del_buf_addr_r <= core_req_addr;
				del_buf_data_r <= core_req_wdata;
				del_buf_be_r   <= s0_req_be;
		end
	end

	always @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			del_buf_way_val_r <= 1'b0;
		end else begin
			del_buf_way_val_r <= ~del_buf_dm_access & del_buf_val_r;
		end
	end

	always @(posedge clk) begin
		if(s1_req_val_r & ~del_buf_dm_access) begin
			del_buf_way_vect_r <= lru_way_vect;
		end
	end

	assign {del_buf_tag, del_buf_idx, del_buf_offset} = del_buf_addr_r;


	// -----------------------------------------------------
	// LD
	// -----------------------------------------------------
	assign ld_ren_vect = {`L1_WAY_NUM{(s0_req_val & ~s0_req_nc)}};
	assign ld_raddr    = s0_req_idx;
	assign ld_wen_vect = mau_req_ack & ~mau_ack_nc;
	assign ld_waddr    = s1_req_idx_r;
	assign ld_wdata    = {ld_wr_val, ld_wr_tag};
	assign ld_wr_val   = 1'b1;
	assign ld_wr_tag   = s1_req_tag_r;


	// -----------------------------------------------------
	// LRU
	// -----------------------------------------------------
	assign lru_req = s0_req_val & (~s0_req_nc);
	always @(posedge clk) if(s1_req_val_r) lru_way_vect_r <= lru_way_vect;
	assign lru_way_pos = one_hot_num(lru_way_vect);

	// -----------------------------------------------------
	// DM
	// -----------------------------------------------------
	always @* begin
		if(s0_req_val & s0_req_rd) begin
			dm_en_vect = {`L1_WAY_NUM{1'b1}};
			dm_we_vect = {`L1_WAY_NUM{1'b0}};
			dm_addr    = s0_req_idx;
		end
		else begin
			if(mau_req_ack & ~mau_ack_nc & ~mau_ack_we) begin
				dm_en_vect = lru_way_vect_r;
				dm_we_vect = lru_way_vect_r;
				dm_addr    = s1_req_idx_r;
			end
			else begin
				if(del_buf_val_r && del_buf_way_val_r) begin
					dm_en_vect = del_buf_way_vect_r;
					dm_we_vect = del_buf_way_vect_r;
					dm_addr    = del_buf_idx;
				end
				else begin
					dm_en_vect = lru_way_vect & {`L1_WAY_NUM{del_buf_val_r}};
					dm_we_vect = lru_way_vect;
					dm_addr    = del_buf_idx;
				end
			end
		end
	end

	assign dm_wdata = (mau_req_ack & ~mau_ack_nc & ~mau_ack_we) ? mau_ack_data : {`L1_LINE_SIZE/32{del_buf_data_r}};
	assign dm_wr_be = (mau_req_ack & ~mau_ack_nc & ~mau_ack_we) ? {`L1_LINE_SIZE/8{1'b1}} : del_buf_be_r;

	// -----------------------------------------------------
	// S1
	// -----------------------------------------------------

	always @(posedge clk, negedge rst_n) begin
		if(~rst_n) s1_req_val_r <= 1'b0;
		else if(~stall) s1_req_val_r <= s0_req_val;
		else s1_req_val_r <= ~mau_req_ack ;
	end

	always @(posedge clk) if(~stall) s1_req_we_r    <= (core_req_cop == `CORE_REQ_WRNC) | (core_req_cop == `CORE_REQ_WR);
	always @(posedge clk) if(~stall) s1_req_nc_r    <= s0_req_nc;
	always @(posedge clk) if(~stall) s1_req_addr_r  <= core_req_addr;
	always @(posedge clk) if(~stall) s1_req_wdata_r <= core_req_wdata;
	always @(posedge clk) if(~stall) s1_req_size_r  <= core_req_size;

	assign {s1_req_tag_r, s1_req_idx_r, s1_req_offset_r} = s1_req_addr_r;

	assign stall = (s1_req_we_r) ? (s1_req_val_r & ~lru_hit & ~mau_req_ack) :
																 (s1_req_val_r & ~(lru_hit | del_buf_hit_r));

	// -----------------------------------------------------
	// MAU
	// -----------------------------------------------------

	assign mau_req_val 	 = s1_req_val_r & (s1_req_nc_r | s1_req_we_r | ~(lru_hit | del_buf_hit_r));
	assign mau_req_nc    = s1_req_nc_r;
  assign mau_req_we    = s1_req_we_r;
	assign mau_req_addr  = (s1_req_we_r | s1_req_nc_r) ? s1_req_addr_r : {s1_req_tag_r, s1_req_idx_r, {`CORE_OFFSET_WIDTH{1'b0}}};
	assign mau_req_wdata = s1_req_wdata_r;

	always @* begin
		if     (s1_req_size_r == 1) mau_req_be = 4'b0001;
		else if(s1_req_size_r == 2) mau_req_be = 4'b0011;
		else                     		mau_req_be = 4'b1111;
	end

	always @(posedge clk) mau_req_ack_r  <= mau_req_ack & ~mau_ack_we;
	always @(posedge clk) mau_ack_data_r <= mau_ack_data;
	always @(posedge clk) mau_ack_nc_r   <= mau_ack_nc;

	assign req_ack = lru_hit | del_buf_hit_r | req_we_ack | mau_req_ack_r;
	assign req_we_ack = s1_req_val_r & s1_req_we_r;

	// -----------------------------------------------------
	// CORE
	// -----------------------------------------------------
	assign core_req_ack   = req_ack;
	assign core_line_data = (lru_hit) ? dm_rdata[lru_way_pos] : mau_ack_data_r;
	assign s1_alligned_offset = {s1_req_offset_r[`CORE_OFFSET_WIDTH-1:2], 2'b00};

	always @* begin
		if(del_buf_hit_r) core_ack_data = del_buf_data_r;
		else if(mau_req_ack_r & mau_ack_nc_r) core_ack_data = core_line_data[`L1_LINE_SIZE-1:`L1_LINE_SIZE-`CORE_DATA_WIDTH];
		else core_ack_data = core_line_data[s1_alligned_offset*8+:`CORE_DATA_WIDTH];
	end

	// -----------------------------------------------------
	// MEMORIES
	// -----------------------------------------------------

	genvar way;
	generate
		for(way = 0; way < `L1_WAY_NUM; way = way + 1) begin

			assign {ld_rd_val_vect[way], ld_rd_tag[way]} = ld_rdata[way];
			assign tag_cmp_vect[way] = (ld_rd_tag[way] == s1_req_tag_r);

			// -----------------------------------------------------
			// LD tag memories
			// -----------------------------------------------------
			l1_ld_dp_mem
			#(
				.WIDTH (`L1_LD_MEM_WIDTH),
				.DEPTH (`L1_SET_NUM)
			)
			ld_mem
			(
				.CLK 		(clk),
				.RST_N 	(rst_n),
				.REN    (ld_ren_vect[way]),
				.RADDR  (ld_raddr),
				.RDATA 	(ld_rdata[way]),
				.WEN    (ld_wen_vect[way]),
				.WADDR 	(ld_waddr),
				.WDATA 	(ld_wdata),
				.ready  (ld_ready_vect[way])
			);

			// -----------------------------------------------------
			// Data memories
			// -----------------------------------------------------
			l1_dm_mem
			#(
				.WIDTH (`L1_LINE_SIZE),
				.DEPTH (`L1_SET_NUM)
			)
			dm_mem
			(
				.CLK 		(clk),
				.EN 		(dm_en_vect[way]),
				.ADDR 	(dm_addr),
				.WE 		(dm_we_vect[way]),
				.WBE    (dm_wr_be),
				.WDATA 	(dm_wdata),
				.RDATA 	(dm_rdata[way])
			);
		end
	endgenerate


	l1_lrum lrum
	(
		.clk 					(clk),
		.rst_n 				(rst_n),
		.req 					(lru_req),
 		.idx 					(s0_req_idx),
 		.ready        (lru_ready),
  	.tag_cmp_vect (tag_cmp_vect),
  	.ld_val_vect  (ld_rd_val_vect),
		.hit 					(lru_hit),
		.evict_val   	(lru_evict_val),
		.way_vect 		(lru_way_vect)
	);

	// -----------------------------------------------------------
	// ASSERTIONS
	// -----------------------------------------------------------

	`ifndef SYNTHESYS

	`ifndef NO_L1_ASSERTIONS

		no_req_when_not_ready_p:
			assert property(@(posedge clk) (core_req_val & rst_n) -> cache_ready == 1'b1)
			else $fatal("Received L1D request whenc cache is not ready!");

		offset_allign_p:
			assert property(@(posedge clk) (core_req_val & (core_req_size == 4) & rst_n) -> core_req_addr[1:0] == 0)
			else $fatal("Wrong offset allignment! (4 bytes)");
			assert property(@(posedge clk) (core_req_val & (core_req_size == 2) & rst_n) -> core_req_addr[0] == 0)
			else $fatal("Wrong offset allignment! (2 bytes)");
	`endif

	`endif
endmodule

`endif
