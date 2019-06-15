DFLAGS = -relocation-model=pic -w -O3 -lowmem -g

all: avst.vvp avst.vpi

clean:
	rm -f avst.vvp avst.vpi avst.o tr_db.log avst_adder.vcd

run: avst.vvp avst.vpi
	vvp -M. -mavst avst.vvp \
	+UVM_TESTNAME=adder_avst.random_test # +UVM_VERBOSITY=DEBUG # +UVM_OBJECTION_TRACE

avst.vvp: test_adder_avst.v verilog/*.v
	iverilog -o $@ $^

avst.vpi: adder_avst.d
	ldc2 $(DFLAGS) -shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-ldl $^
