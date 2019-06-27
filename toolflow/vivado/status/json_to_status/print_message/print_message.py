from google.protobuf import text_format
import status_core_pb2

import argparse

parser = argparse.ArgumentParser(description='Prints TaPaSCo status core binaries as human readable text.')
parser.add_argument('filename', type=str)
args=parser.parse_args()

with open(args.filename, 'rb') as f:
    msg = status_core_pb2.Status()
    msg.ParseFromString(f.read())

    print msg