#!/bin/python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
import json
import re
import sys

import argparse

parser = argparse.ArgumentParser()
parser.add_argument('fileandname', type=str, nargs='+')
args = parser.parse_args()

if len(args.fileandname) % 2 != 0:
        print("Please specify the benchmarks as pairs of 'name filename'.")
        sys.exit(1)

textwidth=516.0 * 0.0138889
columnwidth=252.0 * 0.0138889

def latexify(fig_width=None, fig_height=None, columns=1):
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
        fig_height = fig_width*golden_mean # height in inches

    MAX_HEIGHT_INCHES = 8.0
    if fig_height > MAX_HEIGHT_INCHES:
        print("WARNING: fig_height too large:" + str(fig_height) +
              "so will reduce to" + str(MAX_HEIGHT_INCHES) + "inches.")
        fig_height = MAX_HEIGHT_INCHES

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
latexify(columnwidth, columnwidth * 3)

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

        benchmark_read["{} R".format(name)] = r_s
        benchmark_write["{} W".format(name)] = w_s
        benchmark_readwrite["{} RW".format(name)] = rw_s

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

fig, ax = plt.subplots(3, 1)
plt.subplots_adjust(hspace = 0.25)

ax[0].set_xscale("log")
data_r.plot(ax=ax[0])
data_w.plot(ax=ax[0])
data_rw.plot(ax=ax[0])
ax[0].set_xlabel(r'Transfer Size (\si{\byte})')
ax[0].set_ylabel(r'Transfer Speed (\si{\byte\per\second})')

for name, group in interrupt_latency.groupby("Device"):
    group.plot(ax=ax[1], y="Avg", label=name)
    #group.plot(ax=ax[1], y="Max", label="{} Max".format(name))
    #group.plot(ax=ax[1], y="Min", label="{} Min".format(name))

ax[1].set_xlabel(r'Cycle Count')
ax[1].set_ylabel(r'Latency (\si{\micro\second})')


for name, group in job_throughput.groupby("Device"):
    group.plot(ax=ax[2], y="Jobs", x="Threads", label=name)

ax[2].set_xlabel(r'Threads')
ax[2].set_ylabel(r'Jobs Per Second')

plt.savefig('performance.pdf', format='pdf', bbox_inches='tight')