#!/usr/bin/gnuplot
set terminal pdf enhanced size 29.7cm,21cm
set output '<PDF>'

set style data histogram
set style histogram cluster gap 2

set style fill solid border rgb "black"
set auto x
set xtics rotate by 90 right
set xrange [0:*]
set yrange [*:*]
set xlabel 'Approx. Kernel Runtime (us)'
set ylabel 'Speedup (compared to ideal 1 core)'
set grid noxtics ytics
show grid

set datafile separator ","
set key below

set style line 2 lc rgb '#e31a1c'
set style line 3 lc rgb '#1f78b4'
set style line 4 lc rgb '#33a02c'
set style line 5 lc rgb '#fb9a99'
set style line 6 lc rgb '#a6cee3'
set style line 7 lc rgb '#b2df8a'

plot for [i=2:7:1] "<CSV>" using i:xtic(1) title col ls i

