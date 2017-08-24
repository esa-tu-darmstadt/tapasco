set s_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance m32_axi_aclk]]
set m_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance m64_axi_aclk]]
set g_clk [get_clocks -of_objects [get_ports -scoped_to_current_instance s_axi_aclk]]
set_clock_groups -asynchronous -group $g_clk -group $s_clk -group $m_clk