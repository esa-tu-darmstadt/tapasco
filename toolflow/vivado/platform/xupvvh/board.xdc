#The following two properties should be set for every design
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 85.0 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

##############################################
##########           PCIe           ##########
##############################################
set_property PACKAGE_PIN BG23 [get_ports pcie_sys_reset_l]
set_property IOSTANDARD LVCMOS12 [get_ports pcie_sys_reset_l]
set_property PULLUP true [get_ports pcie_sys_reset_l]
set_property PACKAGE_PIN AR14 [get_ports pcie_sys_clk_clk_n]
set_property PACKAGE_PIN AR15 [get_ports pcie_sys_clk_clk_p]
create_clock -period 10.000 -name refclk_100 [get_ports pcie_sys_clk_clk_p]

##############################################
##########    Board Clocks/Reset    ##########
##############################################
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_l]
set_property PACKAGE_PIN F18 [get_ports sys_rst_l]



# Fix PCIe core to SLR0
create_pblock pblock_axi_pcie
resize_pblock pblock_axi_pcie -add SLR0
set_property IS_SOFT TRUE [get_pblocks pblock_axi_pcie]
add_cells_to_pblock pblock_axi_pcie [get_cells [list system_i/host/axi_pcie3_0]]
