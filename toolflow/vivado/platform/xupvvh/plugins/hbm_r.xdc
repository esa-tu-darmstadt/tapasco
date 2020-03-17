# Constraints for right HBM stack

set_property PACKAGE_PIN BH26 [get_ports hbm_ref_clk_1_clk_p]
set_property PACKAGE_PIN BH25 [get_ports hbm_ref_clk_1_clk_n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_1_clk_p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports hbm_ref_clk_1_clk_n]
set_property ODT RTT_48 [get_ports hbm_ref_clk_1_clk_p]
create_clock -period 10 -name hbm_ref_clk_1_clk_p [get_ports hbm_ref_clk_1_clk_p]

set_clock_groups -asynchronous -group [get_clocks hbm_ref_clk_1_clk_p -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out1_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out2_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out3_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out4_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out5_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out6_system_clk_wiz_1 -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks clk_out7_system_clk_wiz_1 -include_generated_clocks]