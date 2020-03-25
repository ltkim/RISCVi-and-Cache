import rv32i_types::*;
`define BAD_OP $fatal("%0t %s %0d: Illegal operation", $time, `__FILE__, `__LINE__)

module cmp
(
input branch_funct3_t cmpop,
input [31:0] rs1_out,
input [31:0] cmpmux_out,
output logic br_en
);

always_comb begin
  br_en = 1'b0;
  unique case (cmpop)
    beq: begin
      br_en = rs1_out == cmpmux_out ? 1'b1 : 1'b0;
    end
    bne: begin
      br_en = rs1_out == cmpmux_out ? 1'b0 : 1'b1;
    end
    blt: begin
      br_en = $signed(rs1_out) < $signed(cmpmux_out) ? 1'b1 : 1'b0;
    end
    bge: begin
      br_en = $signed(rs1_out) < $signed(cmpmux_out) ? 1'b0 : 1'b1;
    end
    bltu: begin
      br_en = rs1_out < cmpmux_out ? 1'b1 : 1'b0;
    end
    bgeu: begin
      br_en = rs1_out < cmpmux_out ? 1'b0 : 1'b1;
    end
    default:
      `BAD_OP;
  endcase
end
endmodule
