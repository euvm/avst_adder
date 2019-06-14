# avst_adder
Example setup for UVM driven Icarus Verilog Simulation

This example contains a single Verilog module DUT that adds all the bytes of data it receives via an simplified Avalon Streaming streaming 
interface. When the last byte of the arbitrary length stream is received, the DUT gives back a four byte sum that it has accumulated via a reverse Avalon Stream.

## Required Software
1. Icarus Verilog version 10.2 or newer
2. Emabedded UVM downloadable from http://uvm.io/download

To run the simulation just go to the checked-out directory and type `make run` on a bash prompt.
