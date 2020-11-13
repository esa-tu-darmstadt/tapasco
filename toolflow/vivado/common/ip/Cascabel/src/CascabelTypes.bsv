package CascabelTypes;

typedef Bit#(8) KID_TYPE;
typedef Bit#(32) JOBID_TYPE;

typedef  64 PACKET_SIZE_BYTES;
typedef Bit#(TMul#(8, PACKET_SIZE_BYTES)) PacketType;

typedef 32 CONFIG_ADDR_WIDTH;
typedef 64 CONFIG_DATA_WIDTH;

typedef enum { LaunchJob, Barrier } KernelType deriving(Eq, Bits, FShow);

typedef struct {
	Bit#(8) magic;
	Bool valid;
	KernelType kerneltype;
	KID_TYPE kernel_id;
	JOBID_TYPE job_id;
	Bit#(3) param_count;
	Bit#(64) param0;
	Bit#(64) param1;
	Bit#(64) param2;
	Bit#(64) param3;
	Bool signal_host;
} Job deriving(Bits, Eq, FShow);

typedef struct {
	JOBID_TYPE job_id;
	Bit#(64) result;
} JobResult deriving(Bits, Eq, FShow);

endpackage
