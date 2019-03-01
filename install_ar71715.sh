#!/bin/env bash

set -e

if [ -z "$TAPASCO_HOME" ]
then
    echo "Error: \$TAPASCO_HOME is empty"
    exit 1
fi

patchfile="AR71715.zip"
patchdir="$TAPASCO_HOME/patches/AR71715/"

if [ -d "$patchdir" ]; then
    echo "Error: $patchdir already exists"
    exit 1
fi

echo "Download patch..."
curl -s https://s3.amazonaws.com/aws-fpga-developer-ami/1.5.0/Patches/$patchfile -o $patchfile

echo "Extracting patch..."
mkdir -p $patchdir
unzip $patchfile -d $patchdir
rm $patchfile

echo "--------------------------------------"
echo "Activate patch with:"
cmd="export XILINX_PATH=\"\$TAPASCO_HOME/patches/AR71715/sdx/\""
echo $cmd

