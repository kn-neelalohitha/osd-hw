
module dii_buffer
  #(parameter WIDTH=16,
    parameter SIZE=4,
    parameter FULLPACKET=0)
   (
    input clk,
    input rst,

    output logic [$clog2(SIZE)-1:0] packet_size,

    dii_channel in,
    dii_channel out
    );

   // Signals for fifo
   logic [WIDTH-1:0] fifo_data [0:SIZE-1]; //actual fifo
   logic [SIZE-1:0]  fifo_last; //actual fifo
   logic [WIDTH-1:0] nxt_fifo_data [0:SIZE-1];
   logic [SIZE-1:0]  nxt_fifo_last;
   
   reg [SIZE:0]      fifo_write_ptr;
   
   logic             pop;
   logic             push;
   logic             full_packet;

   logic [SIZE-1:0]   valid;
   always_comb begin : valid_comb
      integer i;
      // Set first element
      valid[SIZE-1] = fifo_write_ptr[SIZE];
      for (i = SIZE - 2; i >= 0; i = i - 1) begin
         valid[i] = fifo_write_ptr[i+1] | valid[i+1];
      end
   end
   
   assign full_packet = |(fifo_last & valid); 

   assign pop = out.valid & out.ready;
   assign push = in.valid & in.ready;

   assign out.data = fifo_data[0][WIDTH-1:0];
   assign out.last = fifo_last[0];
   assign out.valid = !FULLPACKET ? !fifo_write_ptr[0] : full_packet;

   assign in.ready = !fifo_write_ptr[SIZE];

   always @(posedge clk) begin
      if (rst) begin
         fifo_write_ptr <= {{SIZE{1'b0}},1'b1};
      end else if (push & !pop) begin
         fifo_write_ptr <= fifo_write_ptr << 1;
      end else if (!push & pop) begin
         fifo_write_ptr <= fifo_write_ptr >> 1;
      end
   end

   always @(*) begin : shift_register_comb
      integer i;
      for (i=0;i<SIZE;i=i+1) begin
         if (pop) begin
            if (push & fifo_write_ptr[i+1]) begin
               nxt_fifo_data[i] = in.data;
               nxt_fifo_last[i] = in.last;
            end else if (i<SIZE-1) begin
               nxt_fifo_data[i] = fifo_data[i+1];
               nxt_fifo_last[i] = fifo_last[i+1];
            end else begin
               nxt_fifo_data[i] = fifo_data[i];
               nxt_fifo_last[i] = fifo_last[i];
            end
         end else if (push & fifo_write_ptr[i]) begin
            nxt_fifo_data[i] = in.data;
            nxt_fifo_last[i] = in.last;
         end else begin
            nxt_fifo_data[i] = fifo_data[i];
         end
      end
   end

   always @(posedge clk) begin : shift_register_seq
      integer i;
      for (i=0;i<SIZE;i=i+1) begin
         fifo_data[i] <= nxt_fifo_data[i];
         fifo_last[i] <= nxt_fifo_last[i];
      end
   end

   // Calculate packet size
   always @(*) begin: find_first_one
      integer i;
      integer not_done;
      not_done = 1;
      packet_size = 1;

      for (i=1; i< SIZE; i = i+1) begin
         if (not_done) begin
            if (fifo_last[i-1] && valid[i-1]) begin
               not_done = 0;
               packet_size = i;
            end
         end
      end
   end // block: find_first_one
   
endmodule // dii_buffer

