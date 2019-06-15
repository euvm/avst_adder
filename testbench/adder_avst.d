import esdl;
import uvm;
import std.stdio;
import std.string: format;

class sha_st: uvm_sequence_item
{
  mixin uvm_object_utils;

  @UVM_DEFAULT {
    @rand ubyte data;
    bool end;
  }
   
  this(string name = "sha_st") {
    super(name);
  }

  Constraint! q{
    data >= 0x30;
    data <= 0x7a;
  } cst_ascii;

  override void do_vpi_put(uvm_vpi_iter iter) {
    iter.put_values(data, end);
  }

  override void do_vpi_get(uvm_vpi_iter iter) {
    iter.get_values(data, end);
  }
}

class sha_phrase_seq: uvm_sequence!sha_st
{

  mixin uvm_object_utils;

  @UVM_DEFAULT {
    ubyte[] phrase;
  }

  this(string name="") {
    super(name);
  }

  void set_phrase(string phrase) {
    this.phrase = cast(ubyte[]) phrase;
  }

  bool _is_final;

  bool is_finalized() {
    return _is_final;
  }

  void opOpAssign(string op)(sha_st item) if(op == "~")
    {
      assert(item !is null);
      phrase ~= item.data;
      if (item.end) _is_final = true;
    }
  // task
  override void body() {
    // uvm_info("sha_st_seq", "Starting sequence", UVM_MEDIUM);

    for (size_t i=0; i!=phrase.length; ++i) {
      wait_for_grant();
      req.data = cast(ubyte) phrase[i];
      if (i == phrase.length - 1) req.end = true;
      else req.end = false;
      sha_st cloned = cast(sha_st) req.clone;
      send_request(cloned);
    }
    
    // uvm_info("sha_st", "Finishing sequence", UVM_MEDIUM);
  } // body

  ubyte[] transform() {
    ubyte[] retval;
    uint value;
    foreach (c; phrase) {
      value += c;
    }
    for (int i=4; i!=0; --i) {
      retval ~= cast (ubyte) (value >> (i-1)*8);
    }
    return retval;
  }
}

class sha_st_seq: uvm_sequence!sha_st
{
  @UVM_DEFAULT {
    @rand uint seq_size;
  }

  mixin uvm_object_utils;


  this(string name="") {
    super(name);
    req = sha_st.type_id.create(name ~ ".req");
  }

  Constraint!q{
    seq_size < 64;
    seq_size > 16;
  } seq_size_cst;

  // task
  override void body() {
      for (size_t i=0; i!=seq_size; ++i) {
	wait_for_grant();
	req.randomize();
	if (i == seq_size - 1) req.end = true;
	else req.end = false;
	sha_st cloned = cast(sha_st) req.clone;
	// uvm_info("sha_st", cloned.sprint, UVM_DEBUG);
	send_request(cloned);
      }
      // uvm_info("sha_st", "Finishing sequence", UVM_DEBUG);
    }

}

class sha_st_driver(string vpi_func): uvm_vpi_driver!(sha_st, vpi_func)
{

  mixin uvm_component_utils;
  
  @UVM_BUILD {
    uvm_analysis_port!sha_st req_analysis;
  }

  this(string name, uvm_component parent = null) {
    super(name,parent);
  }


  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);

    while(true) {
      seq_item_port.get_next_item(req);
      version(NODESIGN) {
	// req.print();
      }
      else {
	// req.print();
	drive_vpi_port.put(req);
      }
      req_analysis.write(req);
      // this.trans_executed(req);
      item_done_event.wait();
      seq_item_port.item_done();
      
    }
  }

  protected void trans_received(sha_st tr) {}
  protected void trans_executed(sha_st tr) {}

}

class sha_scoreboard: uvm_scoreboard
{
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  mixin uvm_component_utils;

  uvm_phase phase_run;

  uint matched;

  sha_phrase_seq[] req_queue;
  sha_phrase_seq[] rsp_queue;

  @UVM_BUILD {
    uvm_analysis_imp!(sha_scoreboard, write_req) req_analysis;
    uvm_analysis_imp!(sha_scoreboard, write_rsp) rsp_analysis;
  }

  override void run_phase(uvm_phase phase) {
    phase_run = phase;
    auto imp = phase.get_imp();
    assert(imp !is null);
    uvm_wait_for_ever();
  }

  void write_req(sha_phrase_seq seq) {
    synchronized(this) {
      req_queue ~= seq;
      assert(phase_run !is null);
      phase_run.raise_objection(this);
      // writeln("Received request: ", matched + 1);
    }
  }

  void write_rsp(sha_phrase_seq seq) {
    synchronized(this) {
      // seq.print();
      rsp_queue ~= seq;
      auto expected = req_queue[matched].transform();
      ++matched;
      // writeln("Ecpected: ", expected[0..64]);
      if (expected == seq.phrase) {
	uvm_info("MATCHED",
		 format("Scoreboard received expected response #%d", matched),
		 UVM_DEBUG);
	uvm_info("REQUEST", format("%s", req_queue[$-1].phrase), UVM_DEBUG);
	uvm_info("RESPONSE", format("%s", rsp_queue[$-1].phrase), UVM_DEBUG);
      }
      else {
	uvm_error("MISMATCHED", "Scoreboard received unmatched response");
	writeln(expected, " ~= ", seq.phrase);
      }
      phase_run.drop_objection(this);
    }
  }

}

class sha_st_monitor(string vpi_func): uvm_vpi_monitor!(sha_st, vpi_func)
{

  mixin uvm_component_utils;
  
  @UVM_BUILD {
    uvm_analysis_port!sha_phrase_seq egress;
  }


  this(string name, uvm_component parent = null) {
    super(name, parent);
    
  }

  sha_phrase_seq seq;

  override void write(sha_st item) {
    if (seq is null) {
      seq = new sha_phrase_seq();
    }

    // item.print();
    seq ~= item;

    if (seq.is_finalized()) {
      // seq.print();
      egress.write(seq);
      seq = null;
    }
  }
  
}


class sha_st_sequencer: uvm_sequencer!sha_st
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class sha_st_agent: uvm_agent
{

  @UVM_BUILD {
    sha_st_sequencer sequencer;
    sha_st_driver!"avst"    driver;

    sha_st_monitor!"avst_req"   req_monitor;
    sha_st_monitor!"avst_rsp"   rsp_monitor;

    sha_scoreboard   scoreboard;
  }
  
  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
    req_monitor.egress.connect(scoreboard.req_analysis);
    rsp_monitor.egress.connect(scoreboard.rsp_analysis);
  }
}

class random_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    sha_st_env env;
  }
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    phase.get_objection.set_drain_time(this, 20.nsec);
    auto rand_sequence = new sha_st_seq("sha_st_seq");

    for (size_t i=0; i!=100; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(sha_st_seq) rand_sequence.clone();
      sequence.start(env.agent.sequencer, null);
    }
    phase.drop_objection(this);
  }
}

class QuickFoxTest: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD sha_st_env env;
  
  override void run_phase(uvm_phase phase) {
    phase.raise_objection(this);
    auto sequence = new sha_phrase_seq("QuickFoxSeq");
    sequence.set_phrase("The quick brown fox jumps over the lazy dog");

    sequence.start(env.agent.sequencer, null);
    phase.drop_objection(this);
  }
}

class sha_st_env: uvm_env
{
  mixin uvm_component_utils;

  @UVM_BUILD private sha_st_agent agent;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

}

void initializeESDL() {
  Vpi.initialize();

  auto test = new uvm_tb;
  test.multicore(0, 4);
  test.elaborate("test");
  test.set_seed(1);
  test.setVpiMode();

  test.start_bg();
}

alias funcType = void function();
shared extern(C) funcType[2] vlog_startup_routines = [&initializeESDL, null];
