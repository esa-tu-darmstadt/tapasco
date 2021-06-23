package CascabelTypes;

typedef Bit#(8) KID_TYPE;
typedef Bit#(32) JOBID_TYPE;

typedef  64 PACKET_SIZE_BYTES;
typedef Bit#(TMul#(8, PACKET_SIZE_BYTES)) PacketType;

typedef 32 CONFIG_ADDR_WIDTH;
typedef 64 CONFIG_DATA_WIDTH;

typedef 512 AXIS_ONCHIP_IN_DATAWIDTH;
typedef   4 AXIS_ONCHIP_USERWIDTH; // use for PE source enumeration
typedef   0 AXIS_ONCHIP_PE_USERWIDTH;

typedef 64 AXIS_ONCHIP_OUT_DATAWIDTH;

Bit#(64) mERGE_RETURN_MAGIC = 721837487;

// MergeCompleter
typedef 128 NumEntries;
typedef Bit#(TLog#(NumEntries)) MergeEntryAddr;

typedef enum { LaunchJob, Barrier } KernelType deriving(Eq, Bits, FShow);

typedef enum { Ignore = 0, ReturnToPE, MergeByPE, MergeByPEandReturn } ReturnAction deriving(Eq, Bits, FShow);

typedef struct {
	KID_TYPE merge_pe; // PE kernel type for merge PE, is called with up to 4 return values; grouped by job_id.
	ReturnAction return_action;
	Maybe#(MergeEntryAddr) bram_addr;
	Bit#(3) merge_param_count;
	Bool merge_param0;
	Bool merge_param1;
	Bool merge_param2;
	Bool merge_param3;
} MergeJob deriving(Bits, Eq, FShow);

typedef struct {
	Bit#(8) magic;
	Bool valid2; // duplicate valid value to be write order independent
`ifdef ONCHIP
	Bit#(AXIS_ONCHIP_USERWIDTH) return_pe; // PE id for signaling/return value
	MergeJob merge;
	Maybe#(MergeJob) parent; // if this is a cascaded merge
	Bool async;
`endif
	KernelType kerneltype;
	KID_TYPE kernel_id;
	JOBID_TYPE job_id;
	Bit#(3) param_count;
	Bit#(64) param0;
	Bit#(64) param1;
	Bit#(64) param2;
	Bit#(64) param3;
	Bool signal_host;
	Bit#(8) irq_number;
	Bool valid; // have it at last position, as PCIe transaction is not atomic -> valid is written last
} Job deriving(Bits, Eq, FShow);

typedef struct {
	JOBID_TYPE job_id;
	Bool signal_host;
	Bit#(8) irq_number;
`ifdef ONCHIP
	Bit#(AXIS_ONCHIP_USERWIDTH) return_pe;
	MergeJob merge;
	Maybe#(MergeJob) parent; // if this is a cascaded merge
	Bool async;
	Bit#(AXIS_ONCHIP_USERWIDTH) running_pe;
`endif
} JobRunning deriving(Bits, Eq, FShow);


typedef struct {
	JOBID_TYPE job_id;
	Bit#(64) result;
`ifdef ONCHIP
	Bit#(AXIS_ONCHIP_USERWIDTH) return_pe;
	MergeJob merge;
	Maybe#(MergeJob) parent; // if this is a cascaded merge
	Bool async;
	Bit#(AXIS_ONCHIP_USERWIDTH) running_pe;
`endif
} JobResult deriving(Bits, Eq, FShow);

endpackage
