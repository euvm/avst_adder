`timescale 1ns / 1ps
`define CLKP 20

module test_adder;

   // Inputs
   reg clk;
   reg reset;
   reg [7:0] data_in;
   reg 	     end_in;
   reg 	     valid_in;
   reg 	     ready_out;

   // Outputs
   wire      ready_in;
   wire [7:0] data_out;
   wire       valid_out;
   wire       end_out;

   // required by pull_sha
   reg [7:0]  tdelay;
   reg [7:0]  tdata;
   reg 	      tend;

   integer    i;

   // Instantiate the Unit Under Test (UUT)
   adder_avst uut (
		    .clk(clk),
		    .reset(reset),
		    .data_in(data_in),
		    .end_in(end_in),
		    .valid_in(valid_in),
		    .ready_out(ready_out),
		    .ready_in(ready_in),
		    .data_out(data_out),
		    .valid_out(valid_out),
		    .end_out(end_out)
		    );

   // BFM
   initial begin: driver
      reg retval;
      #200;
      forever begin
	 @(negedge clk);
	 #5;
	 case ($avst_try_next_item(tdelay, tdata, tend))
	   0: begin
	      for (i = 0; i != tdelay; ++i) begin
		 data_in <= 'hx;
		 end_in <= 'bx;
		 valid_in <= 0;
		 @(negedge clk);
		 #5;
	      end
	      while (ready_in == 0 || reset == 1) begin
		 data_in <= 'hx;
		 end_in <= 'bx;
		 valid_in <= 0;
		 @(posedge clk);
		 #5;
	      end // while (ready_in == 0 || reset == 1)
	      data_in <= tdata;
	      end_in <= tend;
	      valid_in <= 1;
	      // @(negedge clk);
	      // #5;
	      // end_in <= 0;
	      // valid_in <= 0;
	      @(posedge clk);
	      #5;
	      retval = $avst_item_done(0);
	   end // case: 0
	   default: 
	     begin
		data_in <= 'hx;
		end_in <= 'bx;
		valid_in <= 0;
		@(posedge clk);
		#5;
	     end
	 endcase // case ($avl_try_next_item(tdata, tend))
      end // forever begin
   end // block: driver

   initial begin: rsp_snooper
      #200;
      forever begin
	 @(posedge clk);
	 #2;
	 if (valid_out) begin
	    if ($avst_rsp_put(0, data_out, end_out)) ; // $finish;
	 end
      end
   end // block: snooper
   

   initial begin: req_snooper
      #200;
      forever begin
	 @(posedge clk);
	 #2;
	 if (valid_in) begin
	    if ($avst_req_put(0, data_in, end_in)) ; // $finish;
	 end
      end
   end // block: snooper
   

   
   
   initial begin
      $dumpfile("avst_adder.vcd");
      $dumpvars(0, test_adder);
      $dumpon;
      clk = 0;
      forever begin
	 #(`CLKP/2);
	 clk = ~ clk;
      end // forever begin
   end // initial begin

   initial begin
      #1000000;
      $display("Testbench Timeout");
      $finish;
   end

   initial begin
      reset = 0;
      #100;
      // initialize all signals
      ready_out = 1;
      valid_in = 0;
      end_in = 0;
      data_in = 0;
      reset = 1;
      #100;
      reset = 0;
   end
   


endmodule
