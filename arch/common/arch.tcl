namespace eval arch {
  namespace export create
  namespace export get_address_map
  
  # Returns the address map of the current composition.
  # Format: <INTF> -> <BASE ADDR> <RANGE> <KIND>
  # Kind is either memory, register or master.
  # Must be implemented by Platforms.
  proc get_address_map {offset} {
    if {$offset == ""} { set offset [platform::get_pe_base_address] }
    set ret [dict create]
    set pes [lsort [get_processing_elements]]
    foreach pe $pes {
      puts "  processing $pe registers ..."
      set usrs [lsort [get_bd_addr_segs $pe/* -filter { USAGE == register }]]
      for {set i 0} {$i < [llength $usrs]} {incr i; incr offset 0x10000} {
        set seg [lindex $usrs $i]
        set intf [get_bd_intf_pins -of_objects $seg]
        set range [get_property RANGE $seg]
        ::platform::addressmap::add_processing_element [llength [dict keys $ret]] $offset
        dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind register"
      }
      puts "  processing $pe memories ..."
      set usrs [lsort [get_bd_addr_segs $pe/* -filter { USAGE == memory }]]
      for {set i 0} {$i < [llength $usrs]} {incr i; incr offset 0x10000} {
        set seg [lindex $usrs $i]
        set intf [get_bd_intf_pins -of_objects $seg]
        set range [get_property RANGE $seg]
        ::platform::addressmap::add_processing_element [llength [dict keys $ret]] $offset
        dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $offset $range] kind memory"
      }

      puts "  processing $pe masters ..."
      set masters [lsort [tapasco::get_aximm_interfaces $pe]]
      foreach intf $masters {
        set space [get_bd_addr_spaces -of_objects $intf]
        if {$space != {}} {
          set off [get_property OFFSET $space]
          if {$off == ""} { set off 0 }
          set range [get_property RANGE $space]
          if {$range == ""} { error "no range found on $space for $intf!" }
          dict set ret $intf "interface $intf [format "offset 0x%08x range 0x%08x" $off $range] kind master"
        } else {
          puts "  no address spaces found on $intf, continuing ..."
        }
      }
    }
    return $ret
  }
}
