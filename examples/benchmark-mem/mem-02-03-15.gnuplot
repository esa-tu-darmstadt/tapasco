#!/usr/bin/gnuplot
set terminal pdf enhanced size 21cm,29cm
set output 'mem-02-03-15.pdf'

set multiplot layout 2, 1 title "TPC API Transfer Speed, 02-03-15"
set title "ZC706"

set style data histogram
set style histogram cluster gap 1

set style fill solid border rgb "black"
set auto x
set xtics rotate by 90 right
set xrange [0:*] reverse
set yrange [0:*]
set xlabel 'Allocation Size (KiB)'
set ylabel 'Transfer Speed (MiB/s)'
set grid noxtics ytics
show grid

set datafile separator ","

set key left top invert

plot for [i=4:2:-1] "mem_mtdoom_02-03-15_1530.csv" using i:xtic(1) title col

set title "mountdoom"
plot for [i=4:2:-1] "mem_zc_02-03-15_1530.csv" using i:xtic(1) title col

unset multiplot
