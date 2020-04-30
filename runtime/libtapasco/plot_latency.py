data = {}

data["classic"] = """
            Runtime:          1 cc, Latency:  23.87, Max: 180.00, Min:  18.00, Precision:   0.00, Samples: 38892
            Runtime:          2 cc, Latency:  27.30, Max: 150.00, Min:  19.00, Precision:   0.00, Samples: 34075
            Runtime:          4 cc, Latency:  27.26, Max: 200.00, Min:  19.00, Precision:   0.00, Samples: 34086
            Runtime:          8 cc, Latency:  26.67, Max: 1270.00, Min:  18.00, Precision:   0.00, Samples: 34872
            Runtime:         16 cc, Latency:  27.71, Max: 155.00, Min:  18.00, Precision:   0.00, Samples: 33687
            Runtime:         32 cc, Latency:  27.24, Max: 102.00, Min:  19.00, Precision:   0.00, Samples: 34216
            Runtime:         64 cc, Latency:  21.91, Max: 317.00, Min:  17.00, Precision:   0.00, Samples: 42306
            Runtime:        128 cc, Latency:  26.05, Max: 182.00, Min:  18.00, Precision:   0.00, Samples: 35551
            Runtime:        256 cc, Latency:  23.09, Max: 133.00, Min:  20.00, Precision:   0.00, Samples: 38024
            Runtime:        512 cc, Latency:  27.22, Max: 368.00, Min:  20.00, Precision:   0.00, Samples: 31990
            Runtime:       1024 cc, Latency:  29.81, Max: 153.00, Min:  22.00, Precision:   0.00, Samples: 27970
            Runtime:       2048 cc, Latency:  31.76, Max: 189.00, Min:  23.00, Precision:   0.00, Samples: 24095
            Runtime:       4096 cc, Latency:  32.97, Max: 1470.00, Min:  24.00, Precision:   0.00, Samples: 19585
            Runtime:       8192 cc, Latency:  33.43, Max: 147.00, Min:  26.00, Precision:   0.00, Samples: 14800
            Runtime:      16384 cc, Latency:  34.97, Max: 956.00, Min:  27.00, Precision:   0.00, Samples: 9810
            Runtime:      32768 cc, Latency:  40.02, Max: 1268.00, Min:  27.00, Precision:   0.00, Samples: 5781
            Runtime:      65536 cc, Latency: 252.84, Max: 1447.00, Min:  28.00, Precision:   0.02, Samples: 5756
            Runtime:     131072 cc, Latency: 296.89, Max: 475.00, Min:  40.00, Precision:   0.02, Samples: 6032
            Runtime:     262144 cc, Latency: 276.65, Max: 489.00, Min:  45.00, Precision:   0.01, Samples: 3751
            Runtime:     524288 cc, Latency: 306.07, Max: 531.00, Min:  70.00, Precision:   0.01, Samples: 1244
            Runtime:    1048576 cc, Latency: 375.31, Max: 460.00, Min:  84.00, Precision:   0.06, Samples: 437
            Runtime:    2097152 cc, Latency: 341.71, Max: 1255.00, Min: 104.00, Precision:   0.01, Samples: 1603
            Runtime:    4194304 cc, Latency: 326.03, Max: 1286.00, Min: 132.00, Precision:   0.09, Samples: 351
            Runtime:    8388608 cc, Latency: 371.12, Max: 548.00, Min:  93.00, Precision:   0.01, Samples: 826
            Runtime:   16777216 cc, Latency: 383.88, Max: 493.00, Min: 257.00, Precision:   0.06, Samples: 193
            Runtime:   33554432 cc, Latency: 389.03, Max: 526.00, Min: 222.00, Precision:   0.08, Samples: 179
            Runtime:   67108864 cc, Latency: 392.98, Max: 558.00, Min: 323.00, Precision:   0.21, Samples:  53
"""

#            Runtime:  134217728 cc, Latency: 374.23, Max: 466.00, Min: 232.00, Precision:   0.18, Samples: 110
#            Runtime:  268435456 cc, Latency: 366.09, Max: 479.00, Min: 224.00, Precision:   0.03, Samples:  98
#"""

data["rust"] = """
            Checking 4 us execution (I 1000): The mean latency is 18.95us ± 0.27us (Min: 14.66, Max: 167.68).
            Checking 8 us execution (I 1000): The mean latency is 19.06us ± 0.20us (Min: 15.64, Max: 141.77).
            Checking 16 us execution (I 1000): The mean latency is 19.77us ± 0.10us (Min: 16.12, Max: 66.96).
            Checking 32 us execution (I 1000): The mean latency is 18.53us ± 0.08us (Min: 15.61, Max: 85.52).
            Checking 64 us execution (I 1000): The mean latency is 18.44us ± 0.04us (Min: 15.58, Max: 27.80).
            Checking 128 us execution (I 1000): The mean latency is 18.38us ± 0.04us (Min: 15.52, Max: 28.23).
            Checking 256 us execution (I 1000): The mean latency is 18.22us ± 0.04us (Min: 15.39, Max: 28.59).
            Checking 512 us execution (I 1000): The mean latency is 18.00us ± 0.04us (Min: 15.13, Max: 28.33).
            Checking 1024 us execution (I 1000): The mean latency is 18.55us ± 0.04us (Min: 17.55, Max: 27.82).
            Checking 2048 us execution (I 1000): The mean latency is 18.83us ± 0.15us (Min: 16.04, Max: 115.28).
            Checking 4096 us execution (I 1000): The mean latency is 19.02us ± 0.04us (Min: 14.97, Max: 30.13).
            Checking 8192 us execution (I 1000): The mean latency is 20.12us ± 0.10us (Min: 16.25, Max: 113.05).
            Checking 16384 us execution (I 1000): The mean latency is 22.55us ± 0.16us (Min: 17.84, Max: 127.35).
            Checking 32768 us execution (I 1000): The mean latency is 22.73us ± 0.11us (Min: 18.08, Max: 120.25).
            Checking 65536 us execution (I 1000): The mean latency is 23.49us ± 0.06us (Min: 19.04, Max: 33.22).
            Checking 131072 us execution (I 1000): The mean latency is 28.47us ± 0.17us (Min: 19.99, Max: 132.92).
            Checking 262144 us execution (I 1000): The mean latency is 215.31us ± 1.71us (Min: 21.90, Max: 368.02).
            Checking 524288 us execution (I 1000): The mean latency is 257.12us ± 2.16us (Min: 36.46, Max: 1338.35).
            Checking 1048576 us execution (I 1000): The mean latency is 234.60us ± 1.61us (Min: 61.18, Max: 400.96).
            Checking 2097152 us execution (I 1000): The mean latency is 259.95us ± 0.80us (Min: 160.01, Max: 894.80).
            Checking 4194304 us execution (I 953): The mean latency is 266.10us ± 0.84us (Min: 73.14, Max: 595.75).
            Checking 8388608 us execution (I 476): The mean latency is 284.50us ± 1.61us (Min: 67.56, Max: 458.18).
            Checking 16777216 us execution (I 238): The mean latency is 263.69us ± 1.10us (Min: 196.73, Max: 361.48).
            Checking 33554432 us execution (I 119): The mean latency is 273.09us ± 2.34us (Min: 176.88, Max: 340.65).
            Checking 67108864 us execution (I 59): The mean latency is 260.80us ± 4.21us (Min: 128.38, Max: 337.62).
            Checking 134217728 us execution (I 29): The mean latency is 203.04us ± 4.97us (Min: 159.47, Max: 274.38).
            Checking 268435456 us execution (I 14): The mean latency is 201.17us ± 9.44us (Min: 155.18, Max: 310.15).
"""

import re
data_parsed = {}

data_parsed["index"] = []

data_parsed["classic"] = []
for l in data["classic"].splitlines():
      pattern = r".*Runtime:\s*(\d+) cc.*Latency:\s*([\d\.]+),.*"
      m = re.match(pattern, l)
      if m:
            data_parsed["index"].append(int(m.group(1)) * 4)
            data_parsed["classic"].append(float(m.group(2)))

data_parsed["rust"] = []
for l in data["rust"].splitlines():
      pattern = r".*Checking\s*(\d+) us.*is\s*([\d\.]+)us.*"
      m = re.match(pattern, l)
      if m:
            data_parsed["rust"].append(float(m.group(2)))
import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
import json
import re

textwidth=336.0
columnwidth=336.0

def set_size(width, fraction=1):
    """ Set aesthetic figure dimensions to avoid scaling in latex.

    Parameters
    ----------
    width: float
            Width in pts
    fraction: float
            Fraction of the width which you wish the figure to occupy

    Returns
    -------
    fig_dim: tuple
            Dimensions of figure in inches
    """
    # Width of figure
    fig_width_pt = width * fraction

    # Convert from pt to inches
    inches_per_pt = 1 / 72.27

    # Golden ratio to set aesthetic figure height
    golden_ratio = (5**.5 - 1) / 2

    # Figure width in inches
    fig_width_in = fig_width_pt * inches_per_pt
    # Figure height in inches
    fig_height_in = fig_width_in * golden_ratio

    fig_dim = (fig_width_in, fig_height_in)

    return fig_dim

sns.set()

nice_fonts = {
        # Use LaTex to write all text"
        "text.usetex": True,
        "font.family": "sans-serif",
        # Use 10pt font in plots, to match 10pt font in document
        "axes.labelsize": 10,
        "font.size": 10,
        # Make the legend/label fonts a little smaller
        "legend.fontsize": 8,
        "xtick.labelsize": 8,
        "ytick.labelsize": 8,
        "text.latex.preamble": [
            r"\usepackage[binary-units=true, per-mode=symbol,exponent-to-prefix=true]{siunitx}",
        ],
}

mpl.rcParams.update(nice_fonts)

fig, ax = plt.subplots(1, 1, figsize=set_size(columnwidth))
df = pd.DataFrame(data_parsed)
ax.set_xscale("log")
df.plot(ax=ax, x="index", y=["classic", "rust"])

ax.set_xlabel(r'Counter Runtime (\si{\nano\second})')
ax.set_ylabel(r'Latency (\si{\micro\second})')

plt.savefig('rust_latency.pdf', format='pdf', bbox_inches='tight')