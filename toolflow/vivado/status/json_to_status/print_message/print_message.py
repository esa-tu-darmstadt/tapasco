from google.protobuf import text_format
from google.protobuf.internal.decoder import _DecodeVarint32
import status_core_pb2

import argparse

parser = argparse.ArgumentParser(description='Prints TaPaSCo status core binaries as human readable text.')
parser.add_argument('filename', type=str)
args=parser.parse_args()

with open(args.filename, 'rb') as f:
    buf = f.read()
    msg_len, new_pos = _DecodeVarint32(buf, 0)
    print "Message is {} bytes long.".format(msg_len)
    msg = status_core_pb2.Status()
    msg.ParseFromString(buf[new_pos:])

    print msg