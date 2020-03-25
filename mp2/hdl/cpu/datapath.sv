`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)
`define BAD_OP $fatal("%0t %s %0d: Illegal operation", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module datapath
(
    input clk,
    input rst,
    input load_mdr,
    input load_ir,
    input load_regfile,
    input load_mar,
    input load_pc,
    input load_data_out,
    input alu_ops aluop,
    input branch_funct3_t cmpop,

    input pcmux::pcmux_sel_t pcmux_sel,
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input marmux::marmux_sel_t marmux_sel,
    input cmpmux::cmpmux_sel_t cmpmux_sel,

    input logic [3:0] wmask,
    input rv32i_word mem_rdata,
    output rv32i_word mem_wdata, // signal used by RVFI Monitor
    output rv32i_word mem_address,
    output rv32i_word mem_addr_unaligned,
    output [2:0] funct3,
    output [6:0] funct7,
    output rv32i_opcode opcode,
    output [4:0] rs1,
    output [4:0] rs2,
    output br_en,
    output rv32i_word marmux_out
);

/******************* Signals Needed for RVFI Monitor *************************/

//other necessary internal logic
rv32i_word mdrreg_out;
rv32i_word pc_out;
rv32i_word alu_out;

rv32i_word pcmux_out;
//rv32i_word marmux_out;
rv32i_word regfilemux_out;
rv32i_word alumux1_out;
rv32i_word alumux2_out;
rv32i_word cmpmux_out;
rv32i_word mem_wdata_unaligned;

rv32i_word mem_addr;
assign mem_addr = mem_address;

logic [4:0] rs1_, rs2_, rd;
logic [31:0] i_imm, s_imm, u_imm, b_imm, j_imm, rs1_out, rs2_out, rs2_aligned;
logic br_en_;

/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor
ir IR(.*,
.load (load_ir),
.in (mdrreg_out),
.rs1 (rs1_),
.rs2 (rs2_),
.rd (rd)
);

mem_write_reg MEM_WRITE(
.*,
.load (load_data_out),
.in (rs2_out),
.out (mem_wdata)
);

register MDR(
.clk  (clk),
.rst (rst),
.load (load_mdr),
.in   (mem_rdata),
.out  (mdrreg_out)
);

pc_register PC (
.*,
.load (load_pc),
.in (pcmux_out),
.out (pc_out)
);

regfile regfile(.*,
.src_a  (rs1_),
.src_b  (rs2_),
.dest (rd),
.in   (regfilemux_out),
.reg_a (rs1_out),
.reg_b (rs2_out),
.load (load_regfile)
);

register MAR(
.*,
.load (load_mar),
.in (marmux_out),
.out (mem_addr_unaligned)
);

assign mem_address = {mem_addr_unaligned[31:2], 2'b00};


/******************************* ALU and CMP *********************************/
alu ALU(
.*,
.f (alu_out),
.a (alumux1_out),
.b (alumux2_out)
);

cmp CMP(
.*,
.br_en (br_en_)
);

/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
  pcmux_out = alu_out;
  marmux_out = pc_out;
  cmpmux_out = rs2_out;
  alumux1_out = rs1_out;
  alumux2_out = i_imm;
  regfilemux_out = alu_out;
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog.  In this case, we actually use
    // Offensive programming --- making simulation halt with a fatal message
    // warning when an unexpected mux select value occurs
    unique case (pcmux_sel)
        pcmux::pc_plus4: pcmux_out = pc_out + 4;
        pcmux::alu_out: pcmux_out = alu_out;
        pcmux::alu_mod2: pcmux_out = {alu_out[31:1], 1'b0};
        default: `BAD_MUX_SEL;
    endcase

    unique case (marmux_sel)
      marmux::pc_out:
        marmux_out = pc_out;
      marmux::alu_out:
        marmux_out = alu_out;
      default: `BAD_MUX_SEL;
    endcase

    unique case (cmpmux_sel)
      cmpmux::rs2_out:
        cmpmux_out = rs2_out;
      cmpmux::i_imm:
        cmpmux_out = i_imm;
      default: `BAD_MUX_SEL;
    endcase

    unique case (alumux1_sel)
      alumux::rs1_out:
        alumux1_out = rs1_out;
      alumux::pc_out:
        alumux1_out = pc_out;
      default: `BAD_MUX_SEL;
    endcase

    unique case (alumux2_sel)
      alumux::i_imm:
        alumux2_out = i_imm;
      alumux::u_imm:
        alumux2_out = u_imm;
      alumux::b_imm:
        alumux2_out = b_imm;
      alumux::s_imm:
        alumux2_out = s_imm;
      alumux::j_imm:
        alumux2_out = j_imm;
      alumux::rs2_out:
        alumux2_out = rs2_out;
      default: `BAD_MUX_SEL;
    endcase

    unique case (regfilemux_sel)
      regfilemux::alu_out:
        regfilemux_out = alu_out;
      regfilemux::br_en:
        regfilemux_out = {28'h0000000, 2'b00, br_en};
      regfilemux::u_imm:
        regfilemux_out = u_imm;
      regfilemux::lw:
        unique case (mem_addr_unaligned[1:0])
          2'b00:
            regfilemux_out = mdrreg_out;
          2'b01:
            regfilemux_out = {8'h00, mdrreg_out[31:8]};
          2'b10:
            regfilemux_out = {16'h0000, mdrreg_out[31:16]};
          2'b11:
            regfilemux_out = {24'h000000, mdrreg_out[31:24]};
        endcase
      regfilemux::lh: begin
        unique case (mem_addr_unaligned[1:0])
          2'b00:
            regfilemux_out = {{16{mdrreg_out[15]}}, mdrreg_out[15:0]};
          2'b01:
            regfilemux_out = {{16{mdrreg_out[23]}}, mdrreg_out[23:8]};
          2'b10:
            regfilemux_out = {{16{mdrreg_out[31]}}, mdrreg_out[31:16]};
          2'b11:
            regfilemux_out = {24'h000000, mdrreg_out[31:24]};
        endcase
      end
      regfilemux::lhu: begin
        unique case (mem_addr_unaligned[1:0])
          2'b00:
            regfilemux_out = {16'h0000, mdrreg_out[15:0]};
          2'b01:
            regfilemux_out = {16'h0000, mdrreg_out[23:8]};
          2'b10:
            regfilemux_out = {16'h0000, mdrreg_out[31:16]};
          2'b11:
            regfilemux_out = {24'h000000, mdrreg_out[31:24]};
        endcase
      end
      regfilemux::lbu: begin
        unique case (mem_addr_unaligned[1:0])
          2'b00:
            regfilemux_out = {24'h000000, mdrreg_out[7:0]};
          2'b01:
            regfilemux_out = {24'h000000, mdrreg_out[15:8]};
          2'b10:
            regfilemux_out = {24'h000000, mdrreg_out[23:16]};
          2'b11:
            regfilemux_out = {24'h000000, mdrreg_out[31:24]};
        endcase
      end
      regfilemux::lb: begin
        unique case (mem_addr_unaligned[1:0])
          2'b00:
            regfilemux_out = {{24{mdrreg_out[7]}}, mdrreg_out[7:0]};
          2'b01:
            regfilemux_out = {{24{mdrreg_out[15]}}, mdrreg_out[15:8]};
          2'b10:
            regfilemux_out = {{24{mdrreg_out[23]}}, mdrreg_out[23:16]};
          2'b11:
            regfilemux_out = {{24{mdrreg_out[31]}}, mdrreg_out[31:24]};
        endcase
      end
      regfilemux::pc_plus4:
        regfilemux_out = pc_out + 4;
      default: `BAD_MUX_SEL;
    endcase
end

assign rs1 = rs1_;
assign rs2 = rs2_;
assign br_en = br_en_;
/*****************************************************************************/
endmodule : datapath
