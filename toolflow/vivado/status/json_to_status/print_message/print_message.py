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

from google.protobuf import text_format
from google.protobuf.internal.decoder import _DecodeVarint32
import status_core_pb2

import argparse

parser = argparse.ArgumentParser(
    description='Prints TaPaSCo status core binaries as human readable text.')
parser.add_argument('filename', type=str)
args = parser.parse_args()

with open(args.filename, 'rb') as f:
    buf = f.read()
    msg_len, new_pos = _DecodeVarint32(buf, 0)
    print("Message is {} bytes long.".format(msg_len))
    msg = status_core_pb2.Status()
    msg.ParseFromString(buf[new_pos:])

    print(msg)
