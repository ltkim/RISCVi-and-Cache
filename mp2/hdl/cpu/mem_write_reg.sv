module mem_write_reg
(
    input clk,
    input rst,
    input load,
    input [31:0] in,
    input logic [3:0] wmask,
    output logic [31:0] out
);

logic [31:0] data = 1'b0;

always_ff @(posedge clk)
begin
    if (rst)
    begin
        data <= '0;
    end
    else if (load)
    begin
        data <= in;
    end
    else
    begin
        data <= data;
    end
end

always_comb
begin
    unique case (wmask)
      default:
        out = data;
      4'b1110:
        out = {data[23:0], 8'h00};
      4'b0001:
        out = {24'h000000, data[7:0]};
      4'b0010:
        out = {16'h0000, data[7:0], 8'h00};
      4'b0100:
        out = {8'h00, data[7:0], 16'h0000};
      4'b1000:
        out = {data[7:0], 24'h000000};
      4'b0011:
        out = {16'h0000, data[15:0]};
      4'b1100:
        out = {data[15:0], 16'h0000};
      4'b0110:
        out = {8'h00, data[15:0], 8'h00};
      4'b0000:
        out = 0;
    endcase
end

endmodule : mem_write_reg
