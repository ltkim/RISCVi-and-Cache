module flip_flop (
  input clk,
  input rst,
  input LD,
  input data_in,
  output data_out
);

logic data;

always_ff @(posedge clk) begin
  if (rst)
    data <= 0;
  else if (LD)
    data <= data_in;
  else
    data <= data;
end

assign data_out = data;

endmodule
