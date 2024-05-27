// This module performs a cubic interpolation of 4 points.
//
// Nate Hancock & Shawn Burner 2024
//
// This module is intended to work exclusively with an upscale
// ratio of 4x, meaning that it can only work in conjunction with
// an architecture that does 4x upscaling of an image. The pipeline
// of this module means that all outputs will have a latency of 7
// cycles, which may be extended if the stall command is given.

module cubic_scale #(parameter bit_depth = 8)
(
 input logic  [bit_depth-1:0]  a0, a1, a2, a3,
 input logic  stall, clk, reset,
 output logic [bit_depth-1:0] data_out
);

   /*****COMPUTE COEFFICIENTS*****/

   // STAGE 0->1 (Reigster inputs)
   reg [bit_depth-1:0] a0_s1, a1_s1, a2_s1, a3_s1;
   
   always @(posedge clk) begin
      if (reset) begin
	 a0_s1 <= '0;
	 a1_s1 <= '0;
	 a2_s1 <= '0;
	 a3_s1 <= '0;
      end
      else if (~stall) begin
	 a0_s1 <= a0;
	 a1_s1 <= a1;
	 a2_s1 <= a2;
	 a3_s1 <= a3;
      end
   end

   // STAGE 1->2 (Compute intermediary values)
   reg [bit_depth+3:0] a1_mult_15_s2, a1_mult_25_s2, a2_mult_15_s2, a2_mult_2_s2;
   reg [bit_depth-1:0] a0_s2, a1_s2, a2_s2, a3_s2;

   always @(posedge clk) begin
      if (reset) begin
	 a0_s2 <= '0;
	 a1_s2 <= '0;
	 a2_s2 <= '0;
	 a3_s2 <= '0;
	 
	 a1_mult_15_s2 <= '0;
	 a1_mult_25_s2 <= '0;
	 a2_mult_15_s2 <= '0;
	 a2_mult_2_s2  <= '0;
      end
      else if (~stall) begin
	 // Pass forward original values
	 a0_s2 <= a0_s1;
	 a1_s2 <= a1_s1;
	 a2_s2 <= a2_s1;
	 a3_s2 <= a3_s1;

	 // Create and pass on intermediaries
	 a1_mult_15_s2 <= {4'b0, a1_s1}       + {5'b0, a1_s1[bit_depth-1:1]};
	 a1_mult_25_s2 <= {3'b0, a1_s1, 1'b0} + {5'b0, a1_s1[bit_depth-1:1]};
	 a2_mult_15_s2 <= {4'b0, a2_s1}       + {5'b0, a2_s1[bit_depth-1:1]};
	 a2_mult_2_s2  <= {3'b0, a2_s1, 1'b0};
      end
   end // always @ (posedge clk)

   // STAGE 2->3 (First-half computation of coefficients)
   reg [bit_depth+3:0] t0_s3, t1_s3, t2_h1_s3, t2_h2_s3, t3_h1_s3, t3_h2_s3;
   
   always @(posedge clk) begin
      if (reset) begin
	 t0_s3 <= '0;
	 t1_s3 <= '0;
	 
	 t2_h1_s3 <= '0;
	 t2_h2_s3 <= '0;
	 t3_h1_s3 <= '0;
	 t3_h2_s3 <= '0;
      end
      else if (~stall) begin
	 // Compute full-coefficients to pass-forward
	 t0_s3 <= {4'b0, a1_s2};
	 t1_s3 <= {5'b0, a2_s2[bit_depth-1:1]} - {5'b0, a0_s2[bit_depth-1:1]};

	 // Compute half coefficients
	 t2_h1_s3 <= ({4'b0, a0_s2} - a1_mult_25_s2);
	 t2_h2_s3 <= a2_mult_2_s2 - {5'b0, a3_s2[bit_depth-1:1]};
	 t3_h1_s3 <= a1_mult_15_s2 - {5'b0, a0_s2[bit_depth-1:1]};
	 t3_h2_s3 <= {5'b0, a3_s2[bit_depth-1:1]} - a2_mult_15_s2;
      end
   end // always @ (posedge clk)

   // STAGE 3->4 (Second-half computation of coefficients)
   reg [bit_depth+3:0] t0_s4, t1_s4, t2_s4, t3_s4;
   
   always @(posedge clk) begin
      if (reset) begin
	 t0_s4 <= '0;
	 t1_s4 <= '0;
	 
	 t2_s4 <= '0;
	 t3_s4 <= '0;
      end
      else if (~stall) begin
	 // Pass forward full-coefficients from previous stage
	 t0_s4 <= t0_s3;
	 t1_s4 <= t1_s3;

	 // Finish computation from half-coefficients
	 t2_s4 <= t2_h1_s3 + t2_h2_s3;
	 t3_s4 <= t3_h1_s3 + t3_h2_s3;
      end
   end // always @ (posedge clk)
         
   /*****FINAL COMPUTATION******/

   // Stage 4->5 (First stage of final comp)
   reg [bit_depth+4:0] t32_s5;
   reg [bit_depth+3:0] t0_s5, t1_s5;
		      
   always @(posedge clk) begin
      if (reset) begin
	 t32_s5 <= '0;
		      
	 t0_s5 <= '0;
	 t1_s5 <= '0;
       end
      else if (~stall) begin
	 // Compute first stage
	 t32_s5 <= t2_s4 + (t3_s4 >> 1);
		
	 // Pass forward coefficients
	 t0_s5 <= t0_s4;
	 t1_s5 <= t1_s4;
      end
   end

   // Stage 5->6 (Second stage of final comp)
   reg [bit_depth+4:0] t321_s6;
   reg [bit_depth+3:0] t0_s6;
		      
   always @(posedge clk) begin
      if (reset) begin
	 t321_s6 <= '0;
	 
	 t0_s6 <= '0;
      end
      else if (~stall) begin
	 // Compute second stage
	 t321_s6 <= t1_s5 + (t32_s5 >> 1);

	 // Pass forward coefficient
	 t0_s6 <= t0_s5; 
      end
   end

   // Stage 6->7 (Final computation + pass-forward)
   reg [bit_depth+4:0] t3210_s7;
   reg [bit_depth+3:0] t0_s7, t321_shift_s7;

   always @(posedge clk) begin
      if (reset) begin
	 t3210_s7 <= '0;
	 t321_shift_s7 <= '0;
		      
	 t0_s7 <= '0;
      end
      else if (~stall) begin
	 // Compute final value & shift value for later comparison
	 t3210_s7 <= t0_s6 + (t321_s6 >> 1);
	 t321_shift_s7 <= t321_s6 >> 1;

	 // Pass forward coefficient
	 t0_s7 <= t0_s6; 
      end
   end

   // Final output & overflow/underflow gating
   always @(*) begin      		

      // If the final result is negative...
      if(t3210_s7 [bit_depth]) begin
	 // ...and the original input values were both positive, set ceiling on data_out
	 if(~t0_s7 [bit_depth] && ~t321_shift_s7[bit_depth]) data_out = {bit_depth{1'b1}};

	 // ...and the original input values resulted in a truly negative result, set floor on data_out
	 else data_out = {bit_depth{1'b0}};
      end

      // Otherwise, send typical data out
      else data_out = t3210_s7 [bit_depth-1:0];
   end
endmodule
	
