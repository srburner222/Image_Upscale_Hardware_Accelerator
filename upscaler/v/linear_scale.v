// This module performs a linear interpolation of two points
//
// Nate Hancock & Shawn Burner 2024
//
// This module is intended to work exclusively with a 4x
// upscale, meaning that it must be used with an architecture
// which does not have more than 1 interpolated pixel between
// real pixels.

module linear_scale #(parameter bit_depth = 8)
(
 input  logic [bit_depth-1:0] a0, a1,
 output logic [bit_depth-1:0] data_out
);
   // Output is average of the inputs
   assign data_out = (a0 >> 1) + (a1 >> 1);
   
endmodule
