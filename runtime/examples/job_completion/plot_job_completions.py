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

from math import sqrt
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
parser.add_argument('file', type=argparse.FileType('r'))
args = parser.parse_args()

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

sns.set()
latexify(columnwidth)

import csv

data_csv = csv.DictReader(args.file)
data = pd.DataFrame(columns=("Byte", "Microseconds"))
for k in data_csv:
    data = data.append({'Byte':int(k["Byte"]), 'Microseconds': float(k["Nanoseconds"]) / 1000.0}, ignore_index=True)

fig, ax = plt.subplots(1, 1)

ax.set_yscale("log")
ax.set_xscale("log")
sns.lineplot(ax=ax, data=data, x="Byte", y="Microseconds", ci="sd")
#data.plot(ax=ax, x="Byte", y="Microseconds")
ax.set_xlabel(r'Transfer Size (\si{\byte})')
ax.set_ylabel(r'Microseconds')

plt.savefig('job_completion.pdf', format='pdf', bbox_inches='tight')
