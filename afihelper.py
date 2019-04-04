#!/usr/bin/env python3

"""
Helper script for creating AFIs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This script allows the user to upload a given .tar-file to an Amazon S3
bucket and to create an AFI (Amazon FPGA Image) from that file.

The AWS environment must be configured, for example by using the AWS CLI
and running `aws configure`, where the required credentials can be entered.

:Copyright: 2019 Micha Ober
"""

import boto3

import os
import uuid
import shutil
import logging
import argparse
import datetime

parser = argparse.ArgumentParser(description='Helper script for creating AFIs')
parser.add_argument('bucket',
    help='name of the target S3 bucket (created when not existing)')
parser.add_argument('tarfile',
    help='filename of the tar file to create an AFI from')
parser.add_argument('name', help='name of the AFI')
parser.add_argument('--dry-run', default=False, action='store_true',
    help='dry run operation')
parser.add_argument('--verbose', default=False, action='store_true',
    help='be more talkative')
parser.add_argument('--description', default=False,
    help='description of the AFI')

args = parser.parse_args()

if args.verbose:
    boto3.set_stream_logger('boto3.resources', logging.DEBUG)

if not os.path.isfile(args.tarfile):
    print('ERROR: File does not exist')
    exit(1)

s3 = boto3.resource('s3')

bucket = s3.Bucket(args.bucket)
if not bucket.creation_date:
    s3.create_bucket(Bucket=args.bucket)

fname = os.path.basename(args.tarfile)
s3.meta.client.upload_file(args.tarfile, args.bucket, fname)

ec2 = boto3.resource('ec2')

token = uuid.uuid4().hex
description = args.description or 'Created from {} at {}'.format(fname, datetime.datetime.now().isoformat())

response = ec2.meta.client.create_fpga_image(
    DryRun=args.dry_run,
    InputStorageLocation={
        'Bucket': args.bucket,
        'Key': fname
    },
    LogsStorageLocation={
        'Bucket': args.bucket,
        'Key': 'logs'
    },
    Description=description,
    Name=args.name,
    ClientToken=token
)

print(response)

if shutil.which('wait_for_afi.py') is not None:
    subprocess.call(['wait_for_afi.py', '--afi', response['FpgaImageId']])

# vim: set expandtab ts=4 sw=4:
