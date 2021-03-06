// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// FILE NAME      : l1_lrum.v
// PROJECT        : Selen
// AUTHOR         : Grigoriy Zhiharev
// AUTHOR'S EMAIL : gregory.zhiharev@gmail.com
// ----------------------------------------------------------------------------
// DESCRIPTION    :
// ----------------------------------------------------------------------------
`ifndef INC_L1_LRUM
`define INC_L1_LRUM

module l1_lrum
(
	input 												clk,
	input 												rst_n,

  // Read stage
	input 												req,
  input 	[`CORE_IDX_WIDTH-1:0] idx,
  output                        ready,

  // Analyze stage
  input   [`L1_WAY_NUM-1:0]     ld_val_vect,
  input   [`L1_WAY_NUM-1:0]     tag_cmp_vect,
	output 												hit,
  output                        evict_val,
	output 	[`L1_WAY_NUM-1:0] 	  way_vect
);

  localparam IDLE   = 1'b0;
  localparam READY  = 1'b1;

  reg                        rst_state_r;
  reg [`CORE_IDX_WIDTH-1:0]  rst_addr_r;
  wire                       wen;
  wire [`CORE_IDX_WIDTH-1:0] waddr;
  wire [`L1_WAY_NUM-1:0]     wdata;

  reg                        req_r;
  reg  [`CORE_IDX_WIDTH-1:0] idx_r;

  reg                        bypass_r;
  reg  [`L1_WAY_NUM-1:0]     lru_used_bypass_r;

  wire [`L1_WAY_NUM-1:0]     lru_used_sram;
  wire [`L1_WAY_NUM-1:0]     lru_used;
  wire [`L1_WAY_NUM-1:0]     lru_used_inv;
  wire [`L1_WAY_NUM-1:0]     lru_used_upd;
 	wire [`L1_WAY_NUM-1:0] 		 lru_used_next;

	wire [`L1_WAY_NUM-1:0] 		 hit_vect;
	wire [`L1_WAY_NUM-1:0] 		 lru_ev_aloc_way_vect;
	wire 											 lru_is_evict;

  // ------------------------------------------------------
  // FUNCTION: ms1_vec
  // ------------------------------------------------------
  //function [`L1_WAY_NUM-1:0] ms1_vec;
  function [0:`L1_WAY_NUM-1] ms1_vec;
    //input [`L1_WAY_NUM-1:0] vec; //when vec==0,ms1_vec=0!
    input [0:`L1_WAY_NUM-1] vec; //when vec==0,ms1_vec=0!
    integer i,j;
    reg     res0;
    for (i=0; i<`L1_WAY_NUM; i=i+1)
      if (i<(`L1_WAY_NUM-1)) begin
        res0=1'b0;
        for (j=i+1; j<`L1_WAY_NUM; j=j+1) res0=res0|vec[j];
        ms1_vec[i]=vec[i]& ~res0;
      end
      else
        ms1_vec[i]=vec[i];
  endfunction

  // ------------------------------------------------------
  // HARDWARE CLEAN
  // ------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      rst_state_r <= IDLE;
    end else begin
      if(rst_state_r == IDLE) begin
        if(rst_addr_r == {`CORE_IDX_WIDTH{1'b1}}) rst_state_r <= READY;
      end
    end
  end
  always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      rst_addr_r <= 0;
    end else begin
      if(rst_state_r == IDLE)
        rst_addr_r <= rst_addr_r + 1;
    end
  end

  assign ready  = ~(rst_state_r == IDLE);
  assign wen    = (rst_state_r == IDLE) ? 1'b1 : req_r;
  assign waddr  = (rst_state_r == IDLE) ? rst_addr_r : idx_r;
  assign wdata = (rst_state_r == IDLE) ? {`L1_WAY_NUM{1'b0}} : lru_used_next;

  // ------------------------------------------------------
  // READ STAGE
  // ------------------------------------------------------

  always @(posedge clk, negedge rst_n)
    if(~rst_n) req_r <= 0;
    else req_r       <= req;

  always @(posedge clk) idx_r <= idx;

  always @(posedge clk,negedge rst_n)
    if(~rst_n)   bypass_r <= 0;
    else if(req) bypass_r <= (idx == idx_r);

  // ------------------------------------------------------
  // ANALYSE STAGE
  // ------------------------------------------------------

  always @(posedge clk,negedge rst_n)
    if(~rst_n)     lru_used_bypass_r <= 0;
    else if(req_r) lru_used_bypass_r <= lru_used_next;

  assign lru_used = (bypass_r) ? lru_used_bypass_r : lru_used_sram;

	assign hit_vect = ld_val_vect & tag_cmp_vect;
  assign hit = |hit_vect & req_r;
  assign way_vect = (hit) ? hit_vect : lru_ev_aloc_way_vect;
  assign lru_is_evict  = &ld_val_vect;
  assign evict_val = ~hit & lru_is_evict;
  assign lru_used_inv = ~lru_used;
  assign lru_ev_aloc_way_vect = (lru_used == 0) ? (`L1_WAY_NUM'b1) : ms1_vec(lru_used_inv);
  assign lru_used_upd  = lru_used | way_vect;
  assign lru_used_next = (&lru_used_upd) ? way_vect : lru_used_upd;

`ifdef PROTO
  // Xilinx ISE sram IP-core
  sram_dp_4x256
`else
  sram_dp
  #(
    .WIDTH (`L1_WAY_NUM),
    .DEPTH (`L1_SET_NUM)
  )
`endif
  mem
  (
    // PORT A
    .clka   (clk),
    .ena    (wen),
    .wea    (1'b1),
    .addra  (waddr),
    .dina   (wdata),
    .douta  (),
    // PORT B
    .clkb   (clk),
    .enb    (req),
    .web    (1'b0),
    .addrb  (idx),
    .dinb   (),
    .doutb  (lru_used_sram)
  );

endmodule

`endif