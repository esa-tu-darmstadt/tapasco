#!/bin/python3
#
# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
#
# This file is part of TaPaSCo 
# (see https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
import json
import re
import sys

import argparse

from math import sqrt

parser = argparse.ArgumentParser()
parser.add_argument('fileandname', type=str, nargs='+')
args = parser.parse_args()

if len(args.fileandname) % 2 != 0:
        print("Please specify the benchmarks as pairs of 'name filename'.")
        sys.exit(1)

columnwidth=250 * 0.0138889

def latexify(fig_width=None, fig_height=None, columns=1, rows=1):
    """Set up matplotlib's RC params for LaTeX plotting.
    Call this before plotting a figure.

    Parameters
    ----------
    fig_width : float, optional, inches
    fig_height : float,  optional, inches
    columns : {1, 2}
    """

    # code adapted from http://www.scipy.org/Cookbook/Matplotlib/LaTeX_Examples

    # Width and max height in inches for IEEE journals taken from
    # computer.org/cms/Computer.org/Journal%20templates/transactions_art_guide.pdf

    assert(columns in [1,2])

    if fig_width is None:
        fig_width = 3.39 if columns==1 else 6.9 # width in inches

    if fig_height is None:
        golden_mean = (sqrt(5)-1.0)/2.0    # Aesthetic ratio
        fig_height = fig_width*golden_mean*rows # height in inches

    params = {'backend': 'ps',
              'text.latex.preamble':
                                     [r'\usepackage{gensymb}',
                                      r'\usepackage[binary-units=true, per-mode=symbol,exponent-to-prefix=true]{siunitx}'],
              'axes.labelsize': 8, # fontsize for x and y labels (was 10)
              'axes.titlesize': 8,
              'font.size': 8, # was 10
              'legend.fontsize': 6, # was 10
              'xtick.labelsize': 8,
              'ytick.labelsize': 8,
              'text.usetex': True,
              'figure.figsize': [fig_width,fig_height],
              'font.family': 'sans-serif'
    }

    mpl.rcParams.update(params)

def format_axes(ax):
    for spine in ['top', 'right']:
        ax.spines[spine].set_visible(False)

    for spine in ['left', 'bottom']:
        ax.spines[spine].set_color(SPINE_COLOR)
        ax.spines[spine].set_linewidth(0.5)

    ax.xaxis.set_ticks_position('bottom')
    ax.yaxis.set_ticks_position('left')

    for axis in [ax.xaxis, ax.yaxis]:
        axis.set_tick_params(direction='out', color=SPINE_COLOR)

    return ax

sns.set()
latexify(columnwidth,None,1,5)

benchmark_read = {}
benchmark_write = {}
benchmark_readwrite = {}

interrupt_latency = pd.DataFrame(columns=['Device', 'Max', 'Min', 'Avg'])

job_throughput = pd.DataFrame(columns=["Device", "Jobs", "Threads"])

files = [(args.fileandname[x], args.fileandname[x + 1]) for x in range(0, len(args.fileandname), 2)]

for name, file in files:
    with open(file, 'r') as f:
        benchmark = json.load(f)
        ts = benchmark["Transfer Speed"]
        index = []
        read = []
        write = []
        readwrite = []
        for t in ts:
            index.append(t["Chunk Size"])
            read.append(t["Read"])
            write.append(t["Write"])
            readwrite.append(t["ReadWrite"])
        r_s = pd.Series([x * 1024 * 1024 for x in read], index)
        w_s = pd.Series([x * 1024 * 1024 for x in write], index)
        rw_s = pd.Series([x * 1024 * 1024 for x in readwrite], index)

        benchmark_read["{}".format(name)] = r_s
        benchmark_write["{}".format(name)] = w_s
        benchmark_readwrite["{}".format(name)] = rw_s

        il = benchmark["Interrupt Latency"]
        index = []
        average = []
        min_lat = []
        max_lat = []
        for l in il:
            index.append(l["Cycle Count"])
            average.append(l["Avg Latency"])
            min_lat.append(l["Min Latency"])
            max_lat.append(l["Max Latency"])

        il = {"Device": [name for _ in range(len(il))], "Max": pd.Series(max_lat, index), "Min": pd.Series(min_lat, index), "Avg": pd.Series(average, index)}
        il = pd.DataFrame(il)
        interrupt_latency = interrupt_latency.append(il)

        js = benchmark["Job Throughput"]
        threads = []
        jobspersecond = []
        for j in js:
            jobspersecond.append(j["Jobs per second"])
            threads.append(j["Number of threads"])
        job_throughput = job_throughput.append(
                pd.DataFrame(
                    {
                        "Device": [name for _ in range(len(js))],
                        "Threads": threads,
                        "Jobs": jobspersecond
                    }
                )
            )

data_r = pd.DataFrame(benchmark_read)
data_w = pd.DataFrame(benchmark_write)
data_rw = pd.DataFrame(benchmark_readwrite)

fig, ax = plt.subplots(5, 1)
#plt.subplots_adjust(hspace = 0.5)

def sizeof_fmt(num, suffix='B'):
    for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)

ax[0].set_xscale("log")
ax[0].get_yaxis().set_major_formatter(
    mpl.ticker.FuncFormatter(lambda x, p: sizeof_fmt(x, suffix="B/s")))
data_r.plot(ax=ax[0])
ax[0].set_xlabel(r'Transfer Size (\si{\byte}) Reads')
ax[0].set_ylabel(r'Transfer Speed')

ax[1].set_xscale("log")
ax[1].get_yaxis().set_major_formatter(
    mpl.ticker.FuncFormatter(lambda x, p: sizeof_fmt(x, suffix="B/s")))
data_w.plot(ax=ax[1])
ax[1].set_xlabel(r'Transfer Size (\si{\byte}) Writes')
ax[1].set_ylabel(r'Transfer Speed')

ax[2].set_xscale("log")
ax[2].get_yaxis().set_major_formatter(
    mpl.ticker.FuncFormatter(lambda x, p: sizeof_fmt(x, suffix="B/s")))
data_rw.plot(ax=ax[2])
ax[2].set_xlabel(r'Transfer Size (\si{\byte}) Reads and Writes')
ax[2].set_ylabel(r'Transfer Speed')

for name, group in interrupt_latency.groupby("Device"):
    group.plot(ax=ax[3], y="Avg", label=name)
    #group.plot(ax=ax[1], y="Max", label="{} Max".format(name))
    #group.plot(ax=ax[1], y="Min", label="{} Min".format(name))

ax[3].set_xlabel(r'Cycle Count')
ax[3].set_ylabel(r'Latency (\si{\micro\second})')


for name, group in job_throughput.groupby("Device"):
    group.plot(ax=ax[4], y="Jobs", x="Threads", label=name)

ax[4].set_xlabel(r'Threads')
ax[4].set_ylabel(r'Jobs Per Second')

fig.tight_layout(h_pad=1)

plt.savefig('performance.pdf', format='pdf', bbox_inches='tight')
