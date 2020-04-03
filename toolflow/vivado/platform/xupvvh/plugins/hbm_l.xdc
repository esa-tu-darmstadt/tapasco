# Constraints for left HBM stack

set_property PACKAGE_PIN BH27 [get_ports hbm_ref_clk_0_clk_p]
set_property PACKAGE_PIN BJ27 [get_ports hbm_ref_clk_0_clk_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_0_clk_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_0_clk_n]
set_property ODT RTT_48 [get_ports hbm_ref_clk_0_clk_p]
create_clock -period 10 -name hbm_ref_clk_0_clk_p [get_ports hbm_ref_clk_0_clk_p]

set_clock_groups -asynchronous -group [get_clocks hbm_ref_clk_0_clk_p -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out1_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out2_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out3_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out4_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out5_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out6_system_clk_wiz_0 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out7_system_clk_wiz_0 -include_generated_clocks]


set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets system_i/hbm/clocking_0/ibuf/U0/IBUF_OUT[0]]