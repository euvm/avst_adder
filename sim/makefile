DFLAGS = -relocation-model=pic -w -O3 # -lowmem -g

all: avst.vvp avst.vpi

clean:
	rm -f avst.vvp avst.vpi avst.o tr_db.log avst_adder.vcd

run: all
	vvp -M. -mavst avst.vvp \
	+UVM_TESTNAME=adder_avst.random_test +UVM_VERBOSITY=DEBUG # +UVM_OBJECTION_TRACE

avst.vvp: ../testbench/test_adder_avst.v ../rtl/*.v
	iverilog -o $@ $^

avst.vpi: ../testbench/adder_avst.d
	ldc2 $(DFLAGS) -shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-ldl $^
