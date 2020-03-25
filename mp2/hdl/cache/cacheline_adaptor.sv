module reg_block #(parameter width)
(
  input clk,
  input reset,
  input LD_data,
  input [width-1:0] data_in,
  output [width-1:0] data_out
);

logic [width-1:0] data;

always_ff @(posedge clk) begin
  if (reset)
    data <= 0;
  else if (LD_data)
    data <= data_in;
  else
    data <= data;
end

assign data_out = data;

endmodule : reg_block




module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input logic read_i,
    input logic write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input resp_i
);

logic LD_data0, LD_data1, LD_data2, LD_data3, LD_read, LD_write, LD_address, LD_line, read_active, write_active;

logic [255:0] line_data;

//blocks for reading from memory to cache
reg_block #(64) block0(.*, .LD_data(LD_data0), .reset(~reset_n), .data_in(burst_i), .data_out(line_o[63:0]));
reg_block #(64) block1(.*, .LD_data(LD_data1), .reset(~reset_n), .data_in(burst_i), .data_out(line_o[127:64]));
reg_block #(64) block2(.*, .LD_data(LD_data2), .reset(~reset_n), .data_in(burst_i), .data_out(line_o[191:128]));
reg_block #(64) block3(.*, .LD_data(LD_data3), .reset(~reset_n), .data_in(burst_i), .data_out(line_o[255:192]));

reg_block #(1) read_ff(.*, .LD_data(LD_read), .reset(~reset_n), .data_in(read_i), .data_out(read_active));
reg_block #(1) write_ff(.*, .LD_data(LD_write), .reset(~reset_n), .data_in(write_i), .data_out(write_active));

reg_block #(32) address_ff(.*, .LD_data(LD_address), .reset(~reset_n), .data_in(address_i), .data_out(address_o));
reg_block #(256) line_ff(.*, .LD_data(LD_line), .reset(~reset_n), .data_in(line_i), .data_out(line_data));



//states for state machine
enum logic [2:0] {HALT, BURST0, BURST1, BURST2, BURST3, DONE} curr_state, next_state;

always_ff @(posedge clk) begin
  if (~reset_n)
    curr_state <= HALT;
  else
    curr_state <= next_state;
end

always_comb begin
  unique case (curr_state)
    HALT: begin
      if (read_i || write_i)
        next_state = BURST0;
      else
        next_state = HALT;
    end
    BURST0: begin
      if (resp_i)
        next_state = BURST1;
      else
        next_state = BURST0;
    end
    BURST1: begin
      if (resp_i)
        next_state = BURST2;
      else
        next_state = BURST1;
    end
    BURST2: begin
      if (resp_i)
        next_state = BURST3;
      else
        next_state = BURST2;
    end
    BURST3: begin
      if (resp_i)
        next_state = DONE;
      else
        next_state = BURST3;
    end
    DONE:
      next_state = HALT;
  endcase
end

always_comb begin
  LD_data0 = 0;
  LD_data1 = 0;
  LD_data2 = 0;
  LD_data3 = 0;
  LD_read = 1'b0;
  LD_write = 1'b0;
  LD_address = 1'b0;
  LD_line = 1'b0;
  read_o = 0;
  write_o = 0;
  burst_o = 0;
  resp_o = 0;

  unique case (curr_state)

    HALT: begin
      LD_read = 1'b1;
      LD_write = 1'b1;
      LD_address = 1'b1;
      LD_line = 1'b1;
    end

    BURST0: begin
      if (read_active && ~write_active) begin
        read_o = 1'b1;
        LD_data0 = 1'b1;
      end
      else if (write_active) begin
        write_o = 1'b1;
        burst_o = line_data[63:0];
      end

    end

    BURST1: begin
      //address_o = address_i + 1'b1;
      if (read_active && ~write_active) begin
        read_o = 1'b1;
        LD_data1 = 1'b1;
      end
      else if (write_active) begin
        write_o = 1'b1;
        burst_o = line_data[127:64];
      end
    end

    BURST2: begin
    //  address_o = address_i + 2;
      if (read_active && ~write_active) begin
        read_o = 1'b1;
        LD_data2 = 1'b1;
      end
      else if (write_active) begin
        write_o = 1'b1;
        burst_o = line_data[191:128];
      end
    end

    BURST3: begin
      //address_o = address_i + 3;
      if (read_active && ~write_active) begin
        read_o = 1'b1;
        LD_data3 = 1'b1;
      end
      else if (write_active) begin
        write_o = 1'b1;
        burst_o = line_data[255:192];

      end
    end

    DONE: begin
      resp_o = 1'b1;
    end

  endcase
end

endmodule : cacheline_adaptor
