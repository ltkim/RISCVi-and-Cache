import rv32i_types::*;

module cpu
(
    input clk,
    input rst,
    input mem_resp,
    input rv32i_word mem_rdata,
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable,
    output rv32i_word mem_address,
    output rv32i_word mem_wdata
);

/******************* Signals Needed for RVFI Monitor *************************/
rv32i_opcode opcode;
logic [2:0] funct3;
logic [6:0] funct7;
logic br_en;
logic [4:0] rs1;
logic [4:0] rs2;
logic mem_resp_ctl;
pcmux::pcmux_sel_t pcmux_sel;
alumux::alumux1_sel_t alumux1_sel;
alumux::alumux2_sel_t alumux2_sel;
regfilemux::regfilemux_sel_t regfilemux_sel;
marmux::marmux_sel_t marmux_sel;
cmpmux::cmpmux_sel_t cmpmux_sel;
alu_ops aluop;
branch_funct3_t cmpop;
logic load_pc;
logic load_ir;
logic load_regfile;
logic load_mar;
logic load_mdr;
logic load_data_out;

logic mem_read_ctl;
logic mem_write_ctl;
logic [3:0] mem_byte_enable_ctl;
logic [31:0] mem_address_ctl;
logic [31:0] mem_address_datapath;
logic [31:0] mem_wdata_datapath;
logic [3:0] wmask;
logic [31:0] marmux_out;
rv32i_word mem_rdata_datapath;
rv32i_word mem_addr_unaligned;
/*****************************************************************************/

/* Instantiate MP 1 top level blocks here */

// Keep control named `control` for RVFI Monitor
control control(
.*,
.mem_resp(mem_resp_ctl),
.mem_write (mem_write_ctl),
.mem_read (mem_read_ctl),
.mem_byte_enable (mem_byte_enable_ctl)
);

// Keep datapath named `datapath` for RVFI Monitor
datapath datapath(
.*,
.mem_address (mem_address_datapath),
.mem_wdata (mem_wdata_datapath),
.mem_rdata (mem_rdata_datapath)
);

always_comb begin
   mem_read = mem_read_ctl;
   mem_write = mem_write_ctl;
   mem_byte_enable = mem_byte_enable_ctl;
   mem_address = mem_address_datapath;
   mem_wdata = mem_wdata_datapath;
   mem_resp_ctl = mem_resp;
   mem_rdata_datapath = mem_rdata;
end

endmodule : cpu
