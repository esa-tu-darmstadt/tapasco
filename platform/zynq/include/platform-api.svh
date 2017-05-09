`ifndef __PLATFORM_API_SVH__
`define __PLATFORM_API_SVH__ 1
  // Simple API to write tests:
  // Phases in C library
  import "DPI-C" context task platform_init();
  import "DPI-C" context task platform_deinit();
  import "DPI-C" context task platform_run(int unsigned idx);
  import "DPI-C" function int unsigned platform_thread_count();
  import "DPI-C" context task platform_irq_handler();
  import "DPI-C" function int unsigned platform_clock_period();
  
  // Exported functions/tasks
  export "DPI-C" task platform_stop;
  export "DPI-C" task platform_get_time;
  export "DPI-C" task platform_wait_cycles;
  export "DPI-C" task platform_read_mem;
  export "DPI-C" task platform_write_mem;
  export "DPI-C" task platform_read_ctl;
  export "DPI-C" task platform_write_ctl;
  export "DPI-C" task platform_write_ctl_and_wait;
  export "DPI-C" task platform_wait_for_event;
  export "DPI-C" task platform_trigger_event;

  event wait_events[1023:0];
  semaphore sm_mem_r = new(1);
  semaphore sm_mem_w = new(1);
  semaphore sm_dat_r = new(1);
  semaphore sm_dat_w = new(1);

  task automatic platform_stop;
    input int result;
    begin
      $display("platform_stop: result = %d", result);
      $display("--- SIMULATION STOPPED @ %d ---", $time);
      /*if (result) begin
        $display("--- TEST PASSED @ %d ---", $time);
      end else begin
        $display("--- TEST FAILED @ %d ---", $time);
      end*/
      platform_deinit();
      $finish;
    end
  endtask

  task automatic platform_get_time;
    output longint t;
    begin
      t = $time;
    end
  endtask

  task automatic platform_read_mem;
    input int unsigned start_addr;
    input int unsigned no_of_bytes;
    output int data[15:0];
    input int t_id;
    begin
      //$display("platform_read_mem: start_addr = 0x%x (%d), 0x%x (%d)",
      //  start_addr, start_addr, no_of_bytes, no_of_bytes);
      read_mem( .start_addr( start_addr ), .no_of_bytes( no_of_bytes ),
        .data( data ), .t_id( t_id ));
    end
  endtask

  task automatic platform_write_mem;
    input int unsigned start_addr;
    input int unsigned no_of_bytes;
    input int data[15:0];
    input int t_id;
    begin
      $display("platform_write_mem: start_addr = 0x%x (%d), 0x%x (%d)",
        start_addr, start_addr, no_of_bytes, no_of_bytes);
      write_mem( .start_addr( start_addr ), .no_of_bytes( no_of_bytes ),
        .data( data ), .t_id( t_id ));
    end
  endtask

  task automatic platform_read_ctl;
    input int unsigned start_addr;
    input int unsigned no_of_bytes;
    output int data[15:0];
    begin
      $display("platform_read_ctl: start_addr = 0x%08x, len = %d", start_addr,
        no_of_bytes);
      read_ctl( .start_addr( start_addr ), .no_of_bytes( no_of_bytes),
        .data( data ) );
    end
  endtask

  task automatic platform_write_ctl;
    input int unsigned start_addr;
    input int unsigned no_of_bytes;
    input int data[15:0];
    begin
      $display("platform_write_ctl: start_addr = 0x%08x, len = 0x%x (%d)",
        start_addr, no_of_bytes, no_of_bytes);
      write_ctl( .start_addr( start_addr ), .no_of_bytes( no_of_bytes ),
        .data( data ) );
    end
  endtask

  task automatic platform_wait_for_event;
    input int unsigned ev_number;
    begin
      $display("platform_wait_for_event: waiting for event #%u @ %d", ev_number, $time);
      wait (wait_events[ev_number].triggered);
      $display("platform_wait_for_event: event #%u occurred", ev_number);
    end
  endtask

  task automatic platform_trigger_event;
    input int unsigned ev_number;
    begin
      $display(" platform_trigger_event: triggering event #%u @ %d", ev_number, $time);
      -> wait_events[ev_number];
    end
  endtask

  task automatic platform_write_ctl_and_wait;
    input int unsigned w_addr;
    input int unsigned w_no_of_bytes;
    input int w_data[15:0];
    input int unsigned ev_number;
    begin
      $display("platform_write_ctl_and_wait: ");
      fork 
	platform_wait_for_event(ev_number);
        platform_write_ctl( .start_addr( w_addr ), .no_of_bytes( w_no_of_bytes ),
          .data( w_data ) );
      join
    end
  endtask


  /****************************************************************************/

  task automatic read_mem;
  input [31:0] start_addr;
  input int unsigned no_of_bytes;
  output int data[15:0];
  input int t_id;
  reg [511:0] din;
  reg [2:0] resp;
  // reg [31:0] t_id;
  begin
    $display("platform_read_mem (%d): reading %d bytes at 0x%08x", t_id, no_of_bytes, start_addr);
    sm_mem_r.get(1);
    system_i.axi_bfm_mem_master.cdn_axi3_master_bfm_inst.READ_BURST(
      t_id, 			// ID
      start_addr,		// ADDR
      (no_of_bytes >> 2) - 1,	// LEN  (word size 4 bytes)
      3'b010,			// SIZE (4 bytes)
      1,			// BURST (incrementing)
      0,			// LOCK
      0,			// CACHE
      0,			// PROT
      din,			// DATA
      resp			// RESP
    );
    sm_mem_r.put(1);
    $display("platform_read_mem: read %d bytes at 0x%08x", no_of_bytes, start_addr);
    for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      data[i] = din[(((i + 1) << 5) - 1) -: 32];
      $display("platform_read_mem (%d): data[%d] = %08x (%d)", t_id, i, data[i], data[i]);
    end
    $display("platform_read_mem (%d): done", t_id);
  end
  endtask

  task automatic write_mem;
  input [31:0] start_addr;
  input int unsigned no_of_bytes;
  input int data[15:0];
  input int t_id;
  reg [2:0] resp;
  reg [511:0] dout;
  // int tmp;
  begin
    $display("platform_write_mem (%d): writing %d bytes to 0x%08x", t_id, no_of_bytes, start_addr);
    for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      $display("platform_write_mem (%d): data[%d] = %08x (%d)", t_id, i, data[i], data[i]);
      dout[(((i + 1) << 5) - 1) -: 32] = data[i];
    end
    /*for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      tmp = dout[(((i + 1) << 5) - 1) -: 32];
      $display("platform_write_mem (%d): dout[%d] = %08x (%d)", t_id, i, tmp, tmp);
    end*/
    $display("platform_write_mem (%d): starting AXI transaction", t_id);
    sm_mem_w.get(1);
    system_i.axi_bfm_mem_master.cdn_axi3_master_bfm_inst.WRITE_BURST_CONCURRENT(
      t_id,			// ID
      start_addr,		// ADDR
      (no_of_bytes >> 2)-1,	// LEN (word size 4 byte)
      3'b010,			// SIZE (4 bytes)
      1,			// BURST (incrementing)
      0, 			// LOCK
      0,			// CACHE
      0,			// PROT
      dout,			// DATA
      no_of_bytes,		// DATASIZE
      resp			// RESP
    );
    sm_mem_w.put(1);
    $display("platform_write_mem (%d): done", t_id);
  end
  endtask

  task automatic read_ctl;
  input [31:0] start_addr;
  input int unsigned no_of_bytes;
  output int data[15:0];
  reg [511:0] din;
  reg [2:0] resp;
  begin
    $display("platform_read_mem: reading %d bytes at 0x%08x", no_of_bytes, start_addr);
    sm_dat_r.get(1);
    // read data
    system_i.ps7.inst.read_data(
      .start_addr( start_addr ),
      .rd_size( no_of_bytes ),
      .rd_data( din ),
      .response( resp )
    );
    sm_dat_r.put(1);
    $display("platform_read_mem: read %d bytes at 0x%08x", no_of_bytes, start_addr);
    for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      data[i] = din[(((i + 1) << 5) - 1) -: 32];
      $display("data[%d] = %08x (%d)", i, data[i], data[i]);
    end
  end
  endtask

  task automatic write_ctl;
  input [31:0] start_addr;
  input int unsigned no_of_bytes;
  input int data[15:0];
  reg [2:0] resp;
  reg [511:0] dout;
  // int tmp;
  begin
    $display("platform_write_ctl: writing %d bytes to 0x%08x", no_of_bytes, start_addr);
    for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      $display("data[%d] = %08x (%d)", i, data[i], data[i]);
      dout[(((i + 1) << 5) - 1) -: 32] = data[i];
    end
    /*for (int i = 0; i < (no_of_bytes >> 2); i = i + 1) begin
      tmp = dout[(((i + 1) << 5) - 1) -: 32];
      $display("dout[%d] = %08x (%d)", i, tmp, tmp);
    end*/
    sm_dat_w.get(1);
    // write data
    system_i.ps7.inst.write_data(
      .start_addr( start_addr ),
      .wr_size( no_of_bytes ),
      .w_data( dout ),
      .response( resp )
    );
    sm_dat_w.put(1);
  end
  endtask

`endif /* __PLATFORM_API_SVH__ */
