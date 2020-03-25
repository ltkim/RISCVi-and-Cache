import rv32i_types::*;

module mp2
(
    input clk,
    input rst,
    input pmem_resp,
    input [63:0] pmem_rdata,
    output logic pmem_read,
    output logic pmem_write,
    output rv32i_word pmem_address,
    output [63:0] pmem_wdata
);

//***CPU signals***//
rv32i_word mem_rdata;
logic mem_read, mem_write, mem_resp;
logic [3:0] mem_byte_enable;
rv32i_word mem_address;
rv32i_word mem_wdata;
logic mem_resp_cpu;
//****************//

//***Cache signals***//
logic [255:0] pmem_rdata_mem, pmem_wdata_mem;
rv32i_word pmem_address_mem;
logic pmem_read_mem, pmem_write_mem, pmem_resp_mem;
//****************//

cpu cpu (
  .*
);

cache cache (
  .*,
  .pmem_resp (pmem_resp_mem),
  .pmem_rdata (pmem_rdata_mem),
  .pmem_wdata (pmem_wdata_mem),
  .pmem_read (pmem_read_mem),
  .pmem_write (pmem_write_mem),
  .pmem_address (pmem_address_mem)
);

cacheline_adaptor cacheline_adaptor (
  .*,
  .reset_n (~rst),
  .line_i (pmem_wdata_mem),
  .line_o (pmem_rdata_mem),
  .resp_i (pmem_resp),
  .resp_o (pmem_resp_mem),
  .address_i (pmem_address_mem),
  .address_o (pmem_address),
  .burst_i (pmem_rdata),
  .burst_o (pmem_wdata),
  .read_i (pmem_read_mem),
  .write_i (pmem_write_mem),
  .read_o (pmem_read),
  .write_o (pmem_write)
);


endmodule : mp2
