module linear_scale #(parameter bit_depth = 8)
(
 input  logic [bit_depth-1:0] a0, a1,
 output logic [bit_depth-1:0] data_out
);
   
   assign data_out = (a0 >> 1) + (a1 >> 1);

endmodule
