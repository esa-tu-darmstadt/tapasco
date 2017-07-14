#!/usr/bin/gnuplot
set terminal pdf enhanced
set output '<PDF>'

set style data histogram
set style histogram cluster gap 1

set style fill solid border rgb "black"
set auto x
set xtics rotate by 90 right
set xrange [0:*] reverse
set yrange [1:*]
set xlabel 'Allocation Size (KiB)'
set ylabel 'Allocation Speed (alloc+dealloc/s)'
set grid noxtics ytics
show grid

set datafile separator ","

set key right top invert
set logscale y

plot for [i=3:2:-1] "<CSV>" using i:xtic(1) title col
