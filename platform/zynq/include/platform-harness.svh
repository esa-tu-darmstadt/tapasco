`ifndef __PLATFORM_HARNESS_SVH__ 
`define __PLATFORM_HARNESS_SVH__ 1
  `include "platform-api.svh"

  `define TIMEOUT			1000000000		// 1000 ms
  `define PROGRESS			100000			// cycles

  reg clk;
  reg rst;
  reg [95:0] progress;
  reg [15:0] irq;

  reg connected;
  initial connected <= 0;

  semaphore sm_irq = new(1);

  task automatic platform_wait_cycles;
    input int unsigned cycles;
    begin
      $display("platform_wait_cycles: %d", cycles);
      #(platform_clock_period() * cycles);
    end
  endtask

  // clock generation
  initial clk <= 1;
  always #(platform_clock_period() >> 1) clk <= ~clk;

  // timeout process
  initial begin
    repeat (`TIMEOUT/platform_clock_period()) @(posedge clk);
    $display("--- SIMULATION TIMEOUT @ %0d ---", $time);
    $display("--- FAILED @ %d ---", $time);
    platform_deinit();
    $finish;
  end

  // progress process
  initial progress <= `PROGRESS;

  always @(posedge clk) begin
    if (rst) begin
      progress <= progress - 1;
      if (progress == 0) begin
        $display("--- PROGRESS: %d cycles @ %0d ---", `PROGRESS, $time);
        progress <= `PROGRESS;
      end
    end
    if (connected) begin
      poll_clients();
    end
  end

  task automatic poll_clients;
    begin
      for(int i = 0; i < platform_thread_count(); i++) begin
        fork
          automatic int id = i;
          begin
            platform_run(id);
          end
        join_none
      end
    end
  endtask

  initial begin
    @(posedge rst) #1;
    while (rst) begin
      $display("platform_irq: waiting for 0 ...");
      system_i.ps7.inst.wait_interrupt(0, irq);
      $display("platform_irq: irq 0 received (status = 0x%b)", irq);
      sm_irq.get(1);
      platform_irq_handler();
      sm_irq.put(1);
      $display("platform_irq: handler 0 done");
    end
  end

  initial begin
    @(posedge rst) #1;
    while (rst) begin
      $display("platform_irq: waiting for 1 ...");
      system_i.ps7.inst.wait_interrupt(1, irq);
      $display("platform_irq: irq 1 received (status = 0x%b)", irq);
      sm_irq.get(1);
      platform_irq_handler();
      sm_irq.put(1);
      $display("platform_irq: handler 1 done");
    end
  end

  // reset generation
  initial begin
    #1 rst <= 1;
    #99 rst <= 0;
    repeat (1000) @(posedge clk);
    rst <= 1;
    repeat (100) @(posedge clk);
    $display("--- RESET PHASE FINISHED @ %0d ---", $time);
    platform_init();
    // system_i.axi_bfm_mem_master.cdn_axi3_master_bfm_inst.set_channel_level_info(1);
    // system_i.axi_bfm_mem_master.cdn_axi3_master_bfm_inst.set_function_level_info(1);
    // system_i.ps7.inst.set_function_level_info("S_AXI_HP1", 1);
    // system_i.ps7.inst.set_channel_level_info("S_AXI_HP1", 1);
    $display("--- CONNECTION PHASE FINISHED @ %0d ---", $time);
    #1 connected <= 1;
  end

  system system_i(
    clk,
    rst
  );

`endif /* __PLATFORM_HARNESS_SVH__ */
