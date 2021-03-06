`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:42:13 03/02/2013 
// Design Name: 
// Module Name:    adder_tree_DSPCOMP 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_DSPCOMP
	#(parameter PIX_BIT=8,
              MASK_WIDTH=7,
              COFCNT_BIT=15,
				  TERM_SIZE=(MASK_WIDTH**2)
    )
	 (
		input wire clk,reset,
		input wire signed [(PIX_BIT+COFCNT_BIT+1)*TERM_SIZE-1:0]   term_in , // products of p*c
	  
		output wire [PIX_BIT:0] q // signed filter output sign+ 8 bit
		
		);

	  ////////////////////////////////////////////////////////////////////
	  // local parameters to establish signals width
	  localparam //TERM_SIZE =(MASK_WIDTH**2), // Number of terms (p*c)
					 RED_TRM_SZ= TERM_SIZE/2,	  // Number of reduced terms
					 WIDTH_IN=45,
				    WIDTH_OUT=48;
     // Signal Declarations
	  // redefining input signals:
	  wire [PIX_BIT+COFCNT_BIT:0] term [0:TERM_SIZE-1];
     // Signal Declarations
	wire [WIDTH_OUT-1:0] 			  term1 [0:7] ; // second stage of adder tree
	  wire [WIDTH_OUT-1:0]			  term2 ;		 // 3rd stage of adder tree
	  wire [WIDTH_OUT-1:0]			  term3 ;       // 4th stage of adder tree
	  // Leftover term pipeline from multiplier array
	  reg  [(PIX_BIT+COFCNT_BIT+1)*20-1:0]		lftovr_pipe_reg ;//0:15 18 = 9 + 9 (2stages)
	  reg	 [(PIX_BIT+COFCNT_BIT+1)*20-1:0]		lftovr_pipe_next;//0:15
	  // left over from the 1st stage of 6-input adder
	  reg  [(WIDTH_IN)*10-1:0] lftovr0_adder_reg,lftovr1_adder_reg; // 9 (1 stage)
	  reg  [(WIDTH_IN)*10-1:0] lftovr0_adder_next,lftovr1_adder_next;
	  //-------------------------------------
	  localparam PK_LEN= TERM_SIZE,
					  PK_WIDTH= PIX_BIT+COFCNT_BIT+1;
	  genvar unpk_idx;
		generate
			for (unpk_idx=0; unpk_idx<(PK_LEN); unpk_idx=unpk_idx+1) 
			begin:UNPACKING
					assign term[unpk_idx][((PK_WIDTH)-1):0] = term_in[((PK_WIDTH)*unpk_idx+(PK_WIDTH-1)):((PK_WIDTH)*unpk_idx)];
			end
		endgenerate
	  
	  
	  
	    // FIRST STAGE:
	  //==========================================================
	  genvar j;
	  generate 
			for(j=0;j<8;j=j+1)
			begin: REDUCED_TERMS
				six_input_adder
					#( .WIDTH_IN(WIDTH_IN), // input bit width
					  .WIDTH_OUT(WIDTH_OUT) // output bit width
					) first_stage_adder_tree
					(
						.clk(clk), //.reset, // clock and reset siganls
						.A({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6][PIX_BIT+COFCNT_BIT]}},term[j*6]}),.B({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6+1][PIX_BIT+COFCNT_BIT]}},term[j*6+1]}),.C({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6+2][PIX_BIT+COFCNT_BIT]}},term[j*6+2]}),.D({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6+3][PIX_BIT+COFCNT_BIT]}},term[j*6+3]}),.E({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6+4][PIX_BIT+COFCNT_BIT]}},term[j*6+4]}),.F({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){term[j*6+5][PIX_BIT+COFCNT_BIT]}},term[j*6+5]}),
						.SUM(term1[j])
					);

			end
	  endgenerate
	  //==========================================================
	  // SECOND STAGE:
	  //==========================================================
				six_input_adder
					#( .WIDTH_IN(WIDTH_IN), // input bit width
					  .WIDTH_OUT(WIDTH_OUT) // output bit width
					) sec_stage_adder_tree
					(
						.clk(clk),// reset, // clock and reset siganls
						.A(term1[0][WIDTH_IN-1:0]),.B(term1[1][WIDTH_IN-1:0]),.C(term1[2][WIDTH_IN-1:0]),.D(term1[3][WIDTH_IN-1:0]),.E(term1[4][WIDTH_IN-1:0]),.F(term1[5][WIDTH_IN-1:0]),
						.SUM(term2)
					);

	  //==========================================================
	  // Third STAGE:
	  //==========================================================
				six_input_adder
					#( .WIDTH_IN(WIDTH_IN), // input bit width
					  .WIDTH_OUT(WIDTH_OUT) // output bit width
					) thrd_stage_adder_tree
					(
						.clk(clk),// reset, // clock and reset siganls
						.A(term2[WIDTH_IN-1:0]),.B({{(WIDTH_IN-PIX_BIT-COFCNT_BIT-1){lftovr_pipe_reg[(PIX_BIT+COFCNT_BIT+1)*20-1]}},lftovr_pipe_reg[(PIX_BIT+COFCNT_BIT+1)*20-1:(PIX_BIT+COFCNT_BIT+1)*19]}),.C(lftovr1_adder_reg[(WIDTH_IN)*10-1:(WIDTH_IN)*9]),.D(lftovr0_adder_reg[(WIDTH_IN)*10-1:(WIDTH_IN)*9]),.E(45'd0),.F(45'd0),
						.SUM(term3)
					);

	  //==========================================================
	  // If odd number of TERM_SIE, the left term should be piplined all the way along with the signals
	  //==========================================================
	  //  seqeuntial circuit for pipe line along with the ready signal
	  always@(posedge clk)
			//if(reset)
			//		begin
					// odd element left over from the adder tree
			//		lftovr_pipe_reg<=0;
			//		//ready_reg      <=0;
			//		end
			//else
					begin
					// odd element left over from the adder tree
					// from multiplier
					lftovr_pipe_reg   <=lftovr_pipe_next;
					// from adder (1st stage)
					lftovr0_adder_reg <= lftovr0_adder_next;
					lftovr1_adder_reg <= lftovr1_adder_next;
					//ready_reg      	<=  ready_next;
					end
		
	  //next_stage logic for pipe line
	  always@(term[TERM_SIZE-1],lftovr_pipe_reg,term1[6],term[7],lftovr0_adder_reg,lftovr1_adder_reg)
	  begin
			// adder:
			lftovr0_adder_next = {lftovr0_adder_reg[(WIDTH_IN)*9-1:0],term1[6][WIDTH_IN-1:0]};
			lftovr1_adder_next = {lftovr1_adder_reg[(WIDTH_IN)*9-1:0],term1[7][WIDTH_IN-1:0]};
			// multiplier:
			lftovr_pipe_next	 =	{lftovr_pipe_reg[(PIX_BIT+COFCNT_BIT+1)*19-1:0],term[TERM_SIZE-1]};
			// ready flag:
			//ready_next		 	 =	{ready_reg[32:0],enable};
	  end
	  // 2nd stage of adder tree signals renaming (5 in array index-descending)
	  //==========================================================
	 /* generate
			for(i=0;i<RED_TRM_SZ;i=i+1)
				begin: SIG_RENAME
				assign addened[i][5]={{(46-PIX_BIT-COFCNT_BIT){reduced_term[i][PIX_BIT+COFCNT_BIT+1]}},reduced_term[i]}; //5=LOG2(RED_TRM_SZ)
				end
	  endgenerate*/
	  //==========================================================
	/*  
	  //Other stages of the adder down to 2 as the array elements are not a power of two
	  //========================================================== 
	  generate
			for(j=5-1;j>=2;j=j-1) //j=LOG2(RED_TRM_SZ)
			begin: ADDER_STAGE_OUTER
				for(i=0;i<(RED_TRM_SZ/(2**(5-j)));i=i+1) //**(LOG2(RED_TRM_SZ)-j
				begin: ADDER_STAGE_INNER
					dsp_adder48 adder_tree(.AIN1(addened[2*i][j+1]), .BIN1(addened[2*i+1][j+1]), .CLK(clk),  .OUT1(addened[i][j]));//.RST(reset),
				end// adder stage inner
			end // adder stage outer
	  endgenerate
	  
	  assign addened[3][2]={{(47-PIX_BIT-COFCNT_BIT){lftovr_pipe_reg[16*(PIX_BIT+COFCNT_BIT+1)-1]}},lftovr_pipe_reg[16*(PIX_BIT+COFCNT_BIT+1)-1:15*(PIX_BIT+COFCNT_BIT+1)]};
	  
	  //Left over of the adder tree stage 1 to 0 ( the odd leftover from term to be included)
	  generate
			for(j=1;j>=0;j=j-1)
			begin: LEFT_OVER_OUTER
				for(i=0;i<2**j;i=i+1)
				begin: LEFT_OVER_INNER
					dsp_adder48 adder_tree_(.AIN1(addened[2*i][j+1]), .BIN1(addened[2*i+1][j+1]), .CLK(clk),  .OUT1(addened[i][j]));//.RST(reset),
				end // left over inner
			end// left over outer
	  endgenerate
	  */
	  // output logic
	  assign q		= {term3[PIX_BIT+15:15]}; //14 in case of averaging .. 15 in case of edge .. 14 is the 1st decimal bit. {addened[0][0][47],addened[0][0][PIX_BIT+13:14]}; 
	  
	  
	  
	  
		
endmodule
