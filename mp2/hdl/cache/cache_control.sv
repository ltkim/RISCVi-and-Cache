module cache_control (
  input logic clk,
  input logic rst,
  input logic HIT,
  input logic way_hit,
  input logic mem_write_cpu,
  input logic mem_read_cpu,
  input logic [1:0] valid_out,
  input logic [1:0] dirty_out,
  input logic pmem_resp,
  input logic lru_data,
  output logic cacheline_read,
  output logic valid_in,
  output logic lru_in,
  output logic dirty_in,
  output logic LD_LRU,
  output logic [1:0] LD_TAG,
  output logic [1:0] LD_DIRTY,
  output logic [1:0] LD_VALID,
  output logic [2:0] W_CACHE_STATUS,
  output logic mem_resp_cpu
);

//use state machine for control logic with 2 always form
enum logic [3:0] {
START, CACHE_R, CACHE_W, CACHE_EVICT,
WRITE_BACK1, WRITE_BACK2, FILL_CACHE, FINAL
} state, next_state;

//update state
always_ff @(posedge clk) begin
  if (rst)
    state <= START;
  else
    state <= next_state;
end

//***next state logic***//
always_comb begin
  next_state = state;
  unique case (state)
    START: begin
      unique case ({mem_read_cpu, mem_write_cpu})
        default:;
        2'b01:
          next_state = CACHE_W;
        2'b10:
          next_state = CACHE_R;
      endcase
    end
    CACHE_R: begin
      unique case (HIT)
        1'b1:
          next_state = START;
        1'b0:
          next_state = CACHE_EVICT;
      endcase
    end
    CACHE_W: begin
      unique case (HIT)
        1'b1:
          next_state = START;
        1'b0:
          next_state = CACHE_EVICT;
      endcase
    end
    CACHE_EVICT: begin
      unique case (dirty_out[lru_data])
        1'b0:
          next_state = FILL_CACHE;
        1'b1:
          next_state = WRITE_BACK1;
      endcase
    end
    FILL_CACHE: begin
      unique case (pmem_resp)
        default:;
        1'b1:
          next_state = FINAL;
      endcase
    end
    WRITE_BACK1: begin
      if (pmem_resp)
        next_state = WRITE_BACK2;
    end
    WRITE_BACK2: begin
      next_state = FILL_CACHE;
    end
    FINAL: begin
      next_state = START;
    end
  endcase
end
//***next state logic***//


always_comb begin
  set_defaults();
  unique case (state)
    START: begin
      //W_CACHE_STATUS[2] = mem_write_cpu & HIT;
    end
    CACHE_R: begin
      LD_LRU = HIT;

      mem_resp_cpu = HIT;
      unique case (way_hit)
        1'b1:
          lru_in = 1'b0;
        1'b0:
          lru_in = 1'b1;
      endcase
    end
    CACHE_W: begin
      W_CACHE_STATUS[2] = mem_write_cpu & HIT;
      mem_resp_cpu = HIT;
      LD_LRU = HIT;
      lru_in = ~way_hit;
      unique case ({HIT, way_hit})
        default:;
        2'b10: begin
          LD_DIRTY[1:0] = 2'b01;
          dirty_in = 1'b1;
        end
        2'b11: begin
          LD_DIRTY[1:0] = 2'b10;
          dirty_in = 1'b1;
        end
      endcase
    end
    CACHE_EVICT: begin
      W_CACHE_STATUS[0] = 1'b1;
    end
    FILL_CACHE: begin
      //let adaptor start writing to cache
      W_CACHE_STATUS = 3'b011;
      cacheline_read = 1'b1;
      LD_TAG[lru_data] = 1'b1;
      valid_in = 1'b1;
      unique case (lru_data)
        1'b1:
          LD_VALID[1:0] = 2'b10;
        1'b0:
          LD_VALID[1:0] = 2'b01;
      endcase
      LD_DIRTY[lru_data] = 1'b1;
      dirty_in = 1'b0;
    end
    WRITE_BACK1: begin
      W_CACHE_STATUS[0] = 1'b1;
    end
    WRITE_BACK2: begin
      LD_DIRTY[lru_data] = 1'b1;
      dirty_in = 1'b0;
    end
    FINAL: begin
      //allow CPU to write if applicable
      W_CACHE_STATUS[2] = mem_write_cpu;

      if (mem_write_cpu) begin
        LD_DIRTY[lru_data] = 1'b1;
        dirty_in = 1'b1;
      end
      //send mem_response
      mem_resp_cpu = 1'b1;

      LD_LRU = 1'b1;
      lru_in = ~lru_data;

    end
  endcase
end

function void set_defaults();
  valid_in = 0;
  lru_in = 0;
  dirty_in = 0;
  cacheline_read = 1'b0;
  LD_TAG = 0;
  LD_DIRTY = 0;
  LD_LRU = 0;
  LD_VALID = 0;
  W_CACHE_STATUS = 0;
  mem_resp_cpu = 0;
endfunction

endmodule : cache_control
