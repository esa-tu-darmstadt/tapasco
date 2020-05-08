# Group A Clocks
create_clock -period 4  -name clk_main_a0 -waveform {0.000 2}  [get_ports clk_main_a0]
create_clock -period 8 -name clk_extra_a1 -waveform {0.000 4} [get_ports clk_extra_a1]
create_clock -period 2.667 -name clk_extra_a2 -waveform {0.000 1.333} [get_ports clk_extra_a2]
create_clock -period 2 -name clk_extra_a3 -waveform {0.000 1} [get_ports clk_extra_a3]

# Group B Clocks
create_clock -period 2.222 -name clk_extra_b0 -waveform {0.000 1.111} [get_ports clk_extra_b0]
create_clock -period 4.444 -name clk_extra_b1 -waveform {0.000 2.222} [get_ports clk_extra_b1]

# Group C Clocks
create_clock -period 6.667 -name clk_extra_c0 -waveform {0.000 3.333} [get_ports clk_extra_c0]
create_clock -period 5 -name clk_extra_c1 -waveform {0.000 2.5} [get_ports clk_extra_c1]
