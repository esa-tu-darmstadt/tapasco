namespace eval ats-checker {
    proc add_ats_checker {} {
        set ats_interface [get_bd_pins -filter {NAME =~ "S_AXIS_CQ_aclk"} -of_objects [get_bd_cells /arch/target_ip_*]]
        regexp {/arch/(.+)/S_AXIS_CQ_aclk} $ats_interface matched ip
        puts "Found ATS IP $ip"
        disconnect_bd_net /arch/design_clk_1 [get_bd_pins /arch/$ip/S_AXIS_CQ_aclk]
        disconnect_bd_net /arch/design_peripheral_aresetn_1 [get_bd_pins /arch/$ip/S_AXIS_CQ_aresetn]
        disconnect_bd_net /arch/design_clk_1 [get_bd_pins /arch/$ip/M_AXIS_RQ_aclk]
        disconnect_bd_net /arch/design_peripheral_aresetn_1 [get_bd_pins /arch/$ip/M_AXIS_RQ_aresetn]
        delete_bd_objs [get_bd_intf_nets /arch/${ip}_M_ATS_AXI]

        connect_bd_intf_net [get_bd_intf_pins host/axi_pcie3_0/m_axis_cq] [get_bd_intf_pins /arch/$ip/S_ATS_AXIS_CQ]
        connect_bd_intf_net [get_bd_intf_pins /arch/$ip/M_ATS_AXIS_RQ] [get_bd_intf_pins host/axi_pcie3_0/s_axis_rq]
        connect_bd_net [get_bd_pins arch/host_clk] [get_bd_pins /arch/$ip/S_AXIS_CQ_aclk]
        connect_bd_net [get_bd_pins arch/host_peripheral_aresetn] [get_bd_pins /arch/$ip/S_AXIS_CQ_aresetn]
        connect_bd_net [get_bd_pins arch/host_clk] [get_bd_pins /arch/$ip/M_AXIS_RQ_aclk]
        connect_bd_net [get_bd_pins arch/host_peripheral_aresetn] [get_bd_pins /arch/$ip/M_AXIS_RQ_aresetn]
        connect_bd_intf_net [get_bd_intf_pins /arch/$ip/M_ATS_AXI] [get_bd_intf_pins host/in_ic/S01_AXI]

        delete_bd_objs [get_bd_intf_nets arch/out_0_M000_AXI] [get_bd_nets arch/design_interconnect_aresetn_1] [get_bd_cells arch/out_0]

        delete_bd_objs [get_bd_addr_segs arch/$ip/M_ATS_AXI/AM_SEG_000]

        assign_bd_address [get_bd_addr_segs {host/axi_pcie3_0/S_AXI/BAR0 }]
    }

    proc set_route {} {
        set_property AXISTEN_IF_ENABLE_MSG_ROUTE 18'h3FFFF [get_cells system_i/host/axi_pcie3_0/inst/pcie3_ip_i/inst/pcie_top_i/pcie_7vx_i/PCIE_3_0_i]
    }
}

if {[tapasco::is_feature_enabled "ATS-PRI"]} {
    tapasco::register_plugin "platform::ats-checker::add_ats_checker" "pre-wrapper"
    tapasco::register_plugin "platform::ats-checker::set_route" "post-synth"
    tapasco::register_plugin "platform::ats-checker::set_route" "post-impl"
}
