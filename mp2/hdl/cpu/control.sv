import rv32i_types::*; /* Import types defined in rv32i_types.sv */
`define BAD_OP $fatal("%0t %s %0d: Illegal operation", $time, `__FILE__, `__LINE__)

module control
(
    input clk,
    input rst,
    input rv32i_opcode opcode,
    input rv32i_word mem_addr_unaligned, //unaligned mem address
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic br_en,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input mem_resp,
    input logic [31:0] marmux_out,
    output pcmux::pcmux_sel_t pcmux_sel,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output regfilemux::regfilemux_sel_t regfilemux_sel,
    output marmux::marmux_sel_t marmux_sel,
    output cmpmux::cmpmux_sel_t cmpmux_sel,
    output alu_ops aluop,
    output branch_funct3_t cmpop,
    output logic load_pc,
    output logic load_ir,
    output logic load_regfile,
    output logic load_mar,
    output logic load_mdr,
    output logic load_data_out,
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable,
    output logic [3:0] wmask
);

/***************** USED BY RVFIMON --- ONLY MODIFY WHEN TOLD *****************/
logic trap;
logic [4:0] rs1_addr, rs2_addr;
logic [3:0] rmask; //wmask;

branch_funct3_t branch_funct3;
store_funct3_t store_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);
assign rs1_addr = rs1;
assign rs2_addr = rs2;

always_comb
begin : trap_check
    trap = 0;
    rmask = '0;
    wmask = '0;

    case (opcode)
        op_lui, op_auipc, op_imm, op_reg:;
        op_jal, op_jalr: begin
          if (mem_addr_unaligned[1:0] != 2'b00)
            trap = 1;
        end
        op_br: begin
            case (branch_funct3)
                beq, bne, blt, bge, bltu, bgeu: begin
                  if (mem_addr_unaligned[1:0])
                    trap = 1;
                //   if (marmux_out[1:0] != 2'b00)
                //     trap = 1;
                end

                default: trap = 1;
            endcase
        end

        op_load: begin
            case (load_funct3)
                lw: begin
                  unique case (mem_addr_unaligned[1:0])
                    default:;
                    2'b00: begin
                      rmask = 4'b1111;
                      trap = 1'b0;
                    end
                    2'b01: begin
                      rmask = 4'b1110;
                      trap = 1'b1;
                    end
                    2'b10: begin
                      rmask = 4'b1100;
                      trap = 1'b1;
                    end
                    2'b11: begin
                      rmask = 4'b1000;
                      trap = 1'b1;
                    end
                  endcase
                end
                lh, lhu: begin
                  unique case (mem_addr_unaligned[1:0])
                    2'b00:
                      rmask = 4'b0011;
                    2'b10:
                      rmask = 4'b1100;
                    2'b11: begin
                      rmask = 4'b1000;
                      trap = 1;
                    end
                    2'b01: begin
                      rmask = 4'b0110;
                      trap = 1;
                    end
                  endcase
                end
                lb, lbu: begin
                  unique case (mem_addr_unaligned[1:0])
                    2'b00:
                      rmask = 4'b0001;
                    2'b01:
                      rmask = 4'b0010;
                    2'b10:
                      rmask = 4'b0100;
                    2'b11:
                      rmask = 4'b1000;
                  endcase
                end
                default: trap = 1;
            endcase
        end

        op_store: begin
            case (store_funct3)
              sw: begin
                unique case (mem_addr_unaligned[1:0])
                2'b00: begin
                  wmask = 4'b1111;
                  trap = 1'b0;
                end
                2'b01: begin
                  wmask = 4'b1110;
                  trap = 1'b1;
                end
                2'b10: begin
                  wmask = 4'b1100;
                  trap = 1'b1;
                end
                2'b11: begin
                  wmask = 4'b1000;
                  trap = 1'b1;
                end
              endcase
              end
              sh: begin
                unique case (mem_addr_unaligned[1:0])
                default;
                  2'b00:
                    wmask = 4'b0011;
                  2'b10:
                    wmask = 4'b1100;
                  2'b11: begin
                    wmask = 4'b1000;
                    trap = 1;
                  end
                  2'b01: begin
                    wmask = 4'b0110;
                    trap = 1;
                  end
                endcase
              end
              sb: begin
                unique case (mem_addr_unaligned[1:0])
                  2'b00:
                    wmask = 4'b0001;
                  2'b01:
                    wmask = 4'b0010;
                  2'b10:
                    wmask = 4'b0100;
                  2'b11:
                    wmask = 4'b1000;
                endcase
              end
              default: trap = 1;
            endcase
        end

        default: trap = 1;
    endcase
end
/*****************************************************************************/

enum logic [3:0] {
  FETCH1, FETCH2, FETCH3,
  DECODE, IMM, REG, LUI, AUIPC, BR,
  CALC_ADDR, LOAD1, LOAD2, STORE1, STORE2,
  JAL, JALR
} state, next_state;

/************************* Function Definitions *******************************/
/**
 *  You do not need to use these functions, but it can be nice to encapsulate
 *  behavior in such a way.  For example, if you use the `loadRegfile`
 *  function, then you only need to ensure that you set the load_regfile bit
 *  to 1'b1 in one place, rather than in many.
 *
 *  SystemVerilog functions must take zero "simulation time" (as opposed to
 *  tasks).  Thus, they are generally synthesizable, and appropraite
 *  for design code.  Arguments to functions are, by default, input.  But
 *  may be passed as outputs, inouts, or by reference using the `ref` keyword.
**/

/**
 *  Rather than filling up an always_block with a whole bunch of default values,
 *  set the default values for controller output signals in this function,
 *   and then call it at the beginning of your always_comb block.
**/
function void set_defaults();
  pcmux_sel = pcmux::pc_plus4;
  alumux1_sel = alumux::rs1_out;
  alumux2_sel = alumux::i_imm;
  regfilemux_sel = regfilemux::alu_out;
  marmux_sel = marmux::pc_out;
  cmpmux_sel = cmpmux::rs2_out;
  aluop = alu_add;
  cmpop = blt;
  load_pc = 1'b0;
  load_ir = 1'b0;
  load_regfile = 1'b0;
  load_mar = 1'b0;
  load_mdr = 1'b0;
  load_data_out = 1'b0;
  mem_write = 1'b0;
  mem_read = 1'b0;
  mem_byte_enable = 4'b1111;

endfunction

/**
 *  Use the next several functions to set the signals needed to
 *  load various registers
**/
function void loadPC(pcmux::pcmux_sel_t sel);
    load_pc = 1'b1;
    pcmux_sel = sel;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
  load_regfile = 1'b1;
  regfilemux_sel = sel;
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
  load_mar = 1'b1;
  marmux_sel = sel;
endfunction

function void loadMDR();
  load_mdr = 1'b1;
endfunction

function void loadIR();
  load_ir = 1'b1;
endfunction

/**
 * SystemVerilog allows for default argument values in a way similar to
 *   C++.
**/
function void setALU(alumux::alumux1_sel_t sel1,
                               alumux::alumux2_sel_t sel2,
                               logic setop, alu_ops op = alu_add);
    /* Student code here */
    alumux1_sel = sel1;
    alumux2_sel = sel2;

    if (setop)
        aluop = op; // else default value
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
  cmpmux_sel = sel;
  cmpop = op;
endfunction

/*****************************************************************************/

always_comb
begin : state_actions
  set_defaults();

  unique case (state)
    FETCH1: begin
      //get PC
      loadMAR(marmux::pc_out);
    end
    FETCH2: begin
      loadMDR();
      mem_read = 1'b1;
    end
    FETCH3: begin
      loadIR();
    end
    DECODE: begin

    end
    CALC_ADDR: begin
      if (opcode == op_load) begin
        //calculate address offset (MAR <-- rs1_out + i_imm)
        setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
        loadMAR(marmux::alu_out);
      end
      else begin
        setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);
        loadMAR(marmux::alu_out);
        load_data_out = 1'b1;
      end
    end
    LOAD1: begin
      loadMDR();
      mem_read = 1'b1;
      unique case (load_funct3)
        default:;
        lb, lbu: begin
          unique case (mem_addr_unaligned[1:0])
            2'b00:
              mem_byte_enable = 4'b0001;
            2'b01:
              mem_byte_enable = 4'b0010;
            2'b10:
              mem_byte_enable = 4'b0100;
            2'b11:
              mem_byte_enable = 4'b1000;
          endcase
        end
        lh, lhu: begin
          unique case (mem_addr_unaligned[1:0])
            2'b00, 2'b01:
              mem_byte_enable = 4'b0011;
            2'b10, 2'b11:
              mem_byte_enable = 4'b1100;
          endcase
        end
      endcase
    end
    LOAD2: begin
      loadPC(pcmux::pc_plus4);
      unique case (load_funct3)
        lb:
          loadRegfile(regfilemux::lb);
        lbu:
          loadRegfile(regfilemux::lbu);
        lh:
          loadRegfile(regfilemux::lh);
        lhu:
          loadRegfile(regfilemux::lhu);
        default:
          loadRegfile(regfilemux::lw);
      endcase
    end
    STORE1: begin
      mem_write = 1'b1;
      unique case (store_funct3)
        default:;
        sh: begin
          unique case (mem_addr_unaligned[1:0])
            2'b00:
              mem_byte_enable = 4'b0011;
            2'b01:
              mem_byte_enable = 4'b0110;
            2'b10, 2'b11:
              mem_byte_enable = 4'b1100;
          endcase
        end
        sb: begin
          unique case (mem_addr_unaligned[1:0])
            2'b00:
              mem_byte_enable = 4'b0001;
            2'b01:
              mem_byte_enable = 4'b0010;
            2'b10:
              mem_byte_enable = 4'b0100;
            2'b11:
              mem_byte_enable = 4'b1000;
          endcase
        end
      endcase
    end
    STORE2: begin
      //get next instruction
      loadPC(pcmux::pc_plus4);
    end
    IMM: begin
      unique case (funct3)
        slt: begin
          //evaluate reg < imm, load into dest reg
          loadRegfile(regfilemux::br_en);
          setCMP(cmpmux::i_imm, blt);
          loadPC(pcmux::pc_plus4);
        end
        sltu: begin
          //unsigned
          loadRegfile(regfilemux::br_en);
          setCMP(cmpmux::i_imm, bltu);
          loadPC(pcmux::pc_plus4);
        end
        sr: begin
          //right shift, arithmetic and logical
          if (funct7[5]) begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_sra);
          end
          else begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_srl);
          end
        end
        default: begin
          //all other arithmetic intructions
          loadRegfile(regfilemux::alu_out);
          loadPC(pcmux::pc_plus4);
          setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_ops'(funct3));
        end
      endcase
    end
    BR: begin
      //branch condition
      if (br_en)
        loadPC(pcmux::alu_out);
      else
        loadPC(pcmux::pc_plus4);

      setCMP(cmpmux::rs2_out, branch_funct3_t'(funct3));
      setALU(alumux::pc_out, alumux::b_imm, 1'b1, alu_add);
    end
    AUIPC: begin
      setALU(alumux::pc_out, alumux::u_imm, 1'b1, alu_add);
      loadPC(pcmux::pc_plus4);
      loadRegfile(regfilemux::alu_out);
    end
    LUI: begin
      loadRegfile(regfilemux::u_imm);
      loadPC(pcmux::pc_plus4);
    end
    REG: begin
      unique case (funct3)
        slt: begin
          //evaluate reg1 < reg2, load into dest reg
          loadRegfile(regfilemux::br_en);
          setCMP(cmpmux::rs2_out, blt);
          loadPC(pcmux::pc_plus4);
        end
        sltu: begin
          //unsigned
          loadRegfile(regfilemux::br_en);
          setCMP(cmpmux::rs2_out, bltu);
          loadPC(pcmux::pc_plus4);
        end
        sr: begin
          //right shift, arithmetic and logical
          if (funct7[5]) begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sra);
          end
          else begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_srl);
          end
        end
        alu_add: begin
          if (funct7[5]) begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sub);
          end
          else begin
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
            setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_add);
          end
        end
        default: begin
          //all other arithmetic intructions
          loadRegfile(regfilemux::alu_out);
          loadPC(pcmux::pc_plus4);
          setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_ops'(funct3));
        end
      endcase
    end

    JAL: begin
      loadPC(pcmux::alu_out);
      setALU(alumux::pc_out, alumux::j_imm, 1'b1, alu_add);
      loadRegfile(regfilemux::pc_plus4);
    end
    JALR: begin
      loadPC(pcmux::alu_mod2);
      setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
      loadRegfile(regfilemux::pc_plus4);
    end
  endcase
end

always_comb begin
  next_state = state;
  unique case (state)
    FETCH1: begin
      next_state = FETCH2;
    end
    FETCH2: begin
      if (mem_resp)
        next_state = FETCH3;
      else
        next_state = FETCH2;
    end
    FETCH3: begin
      next_state = DECODE;
    end
    DECODE: begin
      unique case (opcode)
        op_lui:
          next_state = LUI;
        op_auipc:
          next_state = AUIPC;
        op_br:
          next_state = BR;
        op_load, op_store:
          next_state = CALC_ADDR;
        op_imm:
          next_state = IMM;
        op_reg:
          next_state = REG;
        op_jal:
          next_state = JAL;
        op_jalr:
          next_state = JALR;
        default:
          `BAD_OP;
      endcase
    end
    CALC_ADDR: begin
      unique case (opcode)
        op_store:
          next_state = STORE1;
        op_load:
          next_state = LOAD1;
        default:
          `BAD_OP;
      endcase
    end
    STORE1: begin
      if (mem_resp)
        next_state = STORE2;
      else
        next_state = STORE1;
    end
    LOAD1: begin
      if (mem_resp)
        next_state = LOAD2;
      else
        next_state = LOAD1;
    end
    default:
      next_state = FETCH1;
  endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
  if (rst)
    state <= FETCH1;
  else
    state <= next_state;
end

endmodule : control
