Memory Benchmark
=================

TaPaSCo includes a PE and example programs which can be used to measure the
memory performance.

You first have to import this PE and build a bitstream:
```
tapasco import $TAPSCO_HOME_TOOLFLOW/examples/MemoryBenchmark.zip
tapasco compose [MemoryBenchmark x 1] @ 300MHz -p *your_platform*
```
You can also benchmark Non-DDR memory with this PE, e.g. HBM. For this you need to
connect the PE to the HBM memory as explained [here](tapasco-features.md#HBM).
Be aware that this PE includes two AXI Master Interfaces (M_AXI & M_AXI_BATCH),
you should connect both to HBM.
You can also include multiple MemoryBenchmark-PEs in your design, e.g. to test
the performance of multiple HBM ports in parallel.

## Example Programs

There are two example programs you can use to measure the performance, once
the bitstream is built and loaded onto your FPGA:

### memtest

This program requires one instance of the MemoryBenchmark-PE.
It benchmarks the performance for random accesse and batch accesses, as well as
the latency of read requests.

#### Random Access

For the random access performance the PE continously sends requests to the memory
for a given time (by default 1 second). The requests can either be read requests,
write requests or read and write requests in parallel.
At the end the number of completed requests is used to compute the average IOPS
and transfer rate.
The size of each request is capped at 4096 Bytes.

#### Batch Access

For the batch access performance the PE sends one request to the memory.
This can again be either a read request, a write request or a read and a write
request in parallel.
The time until the request is completed is measured and used to compute the
transfer rate. The example program repeats this multiple times (by default 1.000)
and calculates the average the transfer rate.
The maximum size of the requests is only capped by the available memory.

#### Read Latency

The PE sends one read request to the memory and measures the latency between
sending the request and receiving the first data packet.
Again this is repeated multiple times (by default 100.000) and the minimum,
average and maximum latency is computed.

### memtest-parallel

This program requires at least two instances of the MemoryBenchmark-PE.
It is similar to the `memtest` program, but can use multiple instances
of the PE to measure the performance when using them in parallel. This
is e.g. useful when measuring the performance of HBM.
