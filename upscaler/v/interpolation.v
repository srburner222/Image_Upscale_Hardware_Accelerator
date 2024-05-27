// This module acts as a top-level image interpolation module for a single color channel
//
// Nate Hancock & Shawn Burner 2024
//
// This module employs a sliding-window interpolation architecture,
// where a stream of input pixels come in, which are then placed
// into the appropriate locations in the register, then interpolation
// hardware generates new data as the input pixels pass through.
// This module employs a combination of the linear and cubic interpolation
// algorithms for a more omptimal amount of hardware. Further optimizing
// hardware, this module only functions for 4x upscale (i.e. 2x on horizontal
// and 2x on vertical). For more information on the implemented algorithm, see
// https://ieeexplore.ieee.org/document/9257189. Data is output from this
// module as a stream of output pixels at the same rate as input data, so
// on average, for every one received pixel, 4 must be output.
module interpolation #(parameter bit_depth = 8, parameter v_res = 4, parameter h_res = 4)
(
  input logic 		       clk, reset,
  input logic                  valid_in,		       
  input logic  [bit_depth-1:0] data_in,
  output logic 		       valid_out, ready_out,
  output logic [bit_depth-1:0] data_out 
);

   localparam NEW_H_RES = 2 * h_res;                       // New Horizontal Resolution (output resolution)
   localparam NEW_V_RES = 2 * v_res;                       // New Vertical Resolution (output resolution)
   localparam REG_SIZE  = bit_depth * (NEW_H_RES * 2 + 1); // Overall size of shift register
   localparam STAGES = 7;                                  // Number of pipeline stages in cubic_scale.v
   localparam STAGES_ODD = STAGES % 2;                     // Odness of STAGES
            
   reg [REG_SIZE-1:0] 	         shift_reg;   // Long shift reg for data processing
   reg [$clog2(NEW_V_RES + 3):0] v_count;     // Number of rows processed
   reg [$clog2(NEW_H_RES):0]     h_count;     // Number of data processed in current row
   reg [$clog2(2*NEW_H_RES+1):0] valid_count; // Tracks how many data have passed until valid   
   reg [$clog2(h_res-1):0]       cubic_count; // Tracks the number of passed cubic computations 

   reg [bit_depth-1:0] 	         linear_data; // Linear interpolated data
   reg [bit_depth-1:0] 	         cubic_data;  // Cubic  interpolated data
   
   /*****CONTROLLER*****/

   typedef enum logic [1:0] {Wait, Run, Idle} state;
   state ps, ns;

   logic rst_count, allow_shift, cubic_upcount;

   // Update state
   always @(posedge clk) begin
      if (reset) ps <= Wait;
      else       ps <= ns;
   end

   // State and control logic
   always @(*) begin

      // DEFAULTS
      ns = ps;
      rst_count = 0;
      allow_shift = 0;
      valid_out = 0;
      cubic_upcount = 0;
      
      case(ps)

	// Module is awaiting the start of an image
	Wait: begin

	   // New data is available, begin running
	   if (valid_in) begin
	      ns = Run;
	      allow_shift = 1;
	   end

	   // Keep module in base state
	   else
	     rst_count = 1;
	end

	// Module is actively processing data
	Run: begin

	   // By default, Run implies the shift register can continue, and we are
	   // incrementing our cubic count.
	   allow_shift = 1;
	   cubic_upcount = 1;

	   // If the register has reached the first real piece of data, raise valid_out
	   if (valid_count ==  (2 * NEW_H_RES + 1))
	      valid_out = 1;

	   // If no new data is available, the next position in the register needs data
	   // and the module is not at the end of the frame, stop the register and go
	   // to idle
	   if (~valid_in && ~v_count[0] && ~h_count[0] && (v_count < NEW_V_RES)) begin
	      allow_shift = 0;
	      cubic_upcount = 0;
	      ns = Idle;
	   end

	   // If the final piece of data has been processed, go to Wait
	   else if (v_count == (NEW_V_RES + 2))
	      ns = Wait; // last output data
	end

	// Waiting for new data before processing can continue
	Idle: begin

	   // New data is available, return to Run
	   if (valid_in) begin
	      ns = Run;
	      allow_shift = 1;
	   end
	end
      endcase
   end
   
   /******DATAPATH******/
   
   always @(posedge clk) begin

      // Set all values to zero at reset
      if (reset || rst_count) begin
	 shift_reg    <= 0;
	 v_count      <= 0;
  	 h_count      <= 0;
	 valid_count  <= 0;
	 cubic_count  <= 0;
      end

      // Reset is not given...
      else begin

	 // If the shift reg is moving and we have not reached
	 // valid data, increment valid count.
	 if ((valid_count < (2 * NEW_H_RES + 1)) && allow_shift)
	   valid_count <= valid_count + 1;
	 
	 // Track location in row
	 if ((h_count < NEW_H_RES - 1) && allow_shift)
	   h_count <= h_count + 1;

	 // If row count rolls over, increment vertical counter
	 else if (allow_shift) begin
	   h_count <= 0;
	   v_count <= v_count + 1;
	 end

	 // reset cubic count if a new row is reached
	 if ((cubic_count == h_res - 1) && cubic_upcount && h_count[0])
	   cubic_count <= 0;

	 // If enough data has passed to make use of cubic count, begin
	 // incrementing (NEW_H_RES+5 is an experimental value)
	 else if ((valid_count > NEW_H_RES+5) && h_count[0] && cubic_upcount)
	   cubic_count <= cubic_count + 1;

	 // If the shift register is moving...
	 if (allow_shift) begin
	    
	    // Get rid of MSB and shift all data down by default
	    shift_reg [REG_SIZE-1-bit_depth:0] <= shift_reg [(REG_SIZE-1):bit_depth];
	    
	    // Shift in new data or zeros
	    if (~h_count[0] && ~v_count[0]) // If in an even row and column, add data
	      shift_reg [REG_SIZE-1:REG_SIZE-bit_depth] <= data_in;

	    // Otherwise, add zeros, to be filled with real data later
	    else
	      shift_reg [REG_SIZE-1:REG_SIZE-bit_depth] <= {bit_depth{1'b0}};

	    // Load Linear data (vertical count is even, horizontal count is odd)
	    if (~v_count[0] && h_count[0])
	      shift_reg [(bit_depth*(NEW_H_RES)-1):(bit_depth*(NEW_H_RES-1))] <= linear_data;
	    
	    // Load Cubic data (horizontal count even/odness depends on number of pipeline stages)
	    if (STAGES_ODD ^ h_count[0])
	      shift_reg [(bit_depth*(NEW_H_RES-5-STAGES)-1):(bit_depth*(NEW_H_RES-6-STAGES))] <= cubic_data;
	 end // if (allow_shift)
      end // else: !if(reset || rst_count)
   end // always @ (posedge clk)
   
   logic [bit_depth-1:0] cubic_edge_left, cubic_edge_near_right, cubic_edge_far_right, linear_edge;
   
   // Check for left edge of frame
   assign cubic_edge_left       = (cubic_count == 0)                                           ? {bit_depth{1'b0}} : shift_reg [(bit_depth*(NEW_H_RES-7)-1):(bit_depth*(NEW_H_RES-8))];
   
   // Check for near right edge of frame
   assign cubic_edge_near_right = (cubic_count == (h_res - 1))                                 ? {bit_depth{1'b0}} : shift_reg [(bit_depth*(NEW_H_RES-3)-1):(bit_depth*(NEW_H_RES-4))];
      
   // Check for far right edge of frame
   assign cubic_edge_far_right  = (cubic_count == (h_res - 1)) || (cubic_count == (h_res - 2)) ? {bit_depth{1'b0}} : shift_reg [(bit_depth*(NEW_H_RES-1)-1):(bit_depth*(NEW_H_RES-2))];

   // Check for bottom edge of frame
   assign linear_edge           = (v_count == (NEW_V_RES))                                     ? {bit_depth{1'b0}} : shift_reg [REG_SIZE-1:(REG_SIZE-bit_depth)];

   // Compute linear interpolation based on edge-case computed values
   linear_scale #(.bit_depth(bit_depth)) linear_scale (.a0(linear_edge), 
						       .a1(shift_reg [bit_depth-1:0]), 
						       .data_out(linear_data));

   // Compute cubic interpolation based on edge-case computed values
   cubic_scale  #(.bit_depth(bit_depth)) cubic_scale  (.a0(cubic_edge_left), 
						       .a1(shift_reg [(bit_depth*(NEW_H_RES-5)-1):(bit_depth*(NEW_H_RES-6))]),
						       .a2(cubic_edge_near_right),
						       .a3(cubic_edge_far_right),
						       .clk(clk),
						       .reset(reset),
						       .stall(~allow_shift),
						       .data_out(cubic_data));
   
   // Data out is always the bottom of the shift reg
   assign data_out = shift_reg [bit_depth-1:0];

   // If counts indicate the module is at a real pixel, assert ready_out
   assign ready_out = ~v_count[0] && ~h_count[0];
      
endmodule
