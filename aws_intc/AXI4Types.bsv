// ---------------
// AXI4 Full Types
// ---------------

package AXI4Types;

typedef enum { // access permissions (p.71)
    UNPRIV_SECURE_DATA          = 3'b000,
    UNPRIV_SECURE_INSTRUCTION   = 3'b001,
    UNPRIV_INSECURE_DATA        = 3'b010,
    UNPRIV_INSECURE_INSTRUCTION = 3'b011,
    PRIV_SECURE_DATA            = 3'b100,
    PRIV_SECURE_INSTRUCTION     = 3'b101,
    PRIV_INSECURE_DATA          = 3'b110,
    PRIV_INSECURE_INSTRUCTION   = 3'b111
} AXI4_Prot deriving (Bits,Eq);

typedef enum { // burst size (p. 45)
    B1   = 3'b000,
    B2   = 3'b001,
    B4   = 3'b010,
    B8   = 3'b011,
    B16  = 3'b100,
    B32  = 3'b101,
    B64  = 3'b110,
    B128 = 3'b111
} AXI4_Burst_Size deriving(Bits, Eq);

typedef enum { // memory attribute signaling (p. 59)
    DEVICE_NON_BUFFERABLE                = 4'b0000,
    DEVICE_BUFFERABLE                    = 4'b0001,
    NORMAL_NON_MODIFIABLE_NON_BUFFERABLE = 4'b0010,
    NORMAL_NON_MODIFIABLE_BUFFERABLE     = 4'b0011,
    WRITE_THROUGH_READ_ALLOCATE          = 4'b1110,
    WRITE_THROUGH_WRITE_ALLOCATE         = 4'b1010,
    WRITE_BACK_READ_ALLOCATE             = 4'b1111,
    WRITE_BACK_WRITE_ALLOCATE            = 4'b1011
} AXI4_Rd_Cache deriving(Bits, Eq);

typedef enum { // memory attribute signaling (p. 59)
    DEVICE_NON_BUFFERABLE                = 4'b0000,
    DEVICE_BUFFERABLE                    = 4'b0001,
    NORMAL_NON_MODIFIABLE_NON_BUFFERABLE = 4'b0010,
    NORMAL_NON_MODIFIABLE_BUFFERABLE     = 4'b0011,
    WRITE_THROUGH_READ_ALLOCATE          = 4'b0110,
    WRITE_THROUGH_WRITE_ALLOCATE         = 4'b1110,
    WRITE_BACK_READ_ALLOCATE             = 4'b0111,
    WRITE_BACK_WRITE_ALLOCATE            = 4'b1111
} AXI4_Wr_Cache deriving(Bits, Eq);

// TODO: check AXI4 support for exclusive access
typedef enum { // exclusive accesses (p. 92)
    NORMAL    = 1'b0,
    EXCLUSIVE = 1'b1
} AXI4_Lock deriving(Bits, Eq); 

typedef enum { // read and write response structure (p.54)
    OKAY   = 2'b00, // normal access success
    EXOKAY = 2'b01, // exclusive access okay
    SLVERR = 2'b10, // request ok, but slave returned an error
    DECERR = 2'b11  // decode error (no slave at transaction addr)
} AXI4_Resp deriving (Bits,Eq);

typedef enum { // burst type (p. 46)
    FIXED    = 2'b00,
    INCR     = 2'b01,
    WRAP     = 2'b10,
    RESERVED = 2'b11
} AXI4_Burst_Type deriving(Bits, Eq);

typedef struct {
    Bit#(idw) id;           // O: arid,     optional, default: 0
    Bit#(addrw) addr;       // O: araddr,   required
    Bit#(4) region;         // O: arregion, optional, default: 0
    UInt#(8) len;           // O: arlen,    optional, default: 0 
    AXI4_Burst_Size size;   // O: arsize,   optional, default: bus width
    AXI4_Burst_Type burst;  // O: arburst,  optional, default: INCR
    AXI4_Lock lock;         // O: arlock,   optional, default: NORMAL
    AXI4_Rd_Cache cache;    // O: arcache,  optional, default: DEVICE_NON_BUFFERABLE
    AXI4_Prot prot;         // O: arprot,   required
    Bit#(4) qos;            // O: arqos,    optional, default: 'b0000
    Bit#(userw) user;       // O: aruser,   optional
} AXI4_Rq_Rd#(numeric type addrw, numeric type idw, numeric type userw)
    deriving (Bits,Eq);

typedef struct {
    Bit#(idw)  id;    // I: rid,   optional
    Bit#(dataw) data; // I: rdata, required
    AXI4_Resp resp;   // I: rresp, optional
    Bit#(1) last;     // I: rlast, optional
    Bit#(userw) user; // I: ruser, optional
} AXI4_Rsp_Rd#(numeric type dataw, numeric type idw, numeric type userw)
    deriving (Bits,Eq);

typedef struct {
    Bit#(idw) id;          // O: awid,     optional, default: 0
    Bit#(addrw) addr;      // O: awaddr,   required
    Bit#(4) region;        // O: awregion, optional, default: 0
    UInt#(8) len;          // O: awlen,    optional, default: 0 
    AXI4_Burst_Size size;  // O: awsize,   optional, default: bus width
    AXI4_Burst_Type burst; // O: awburst,  optional, default: INCR
    AXI4_Lock lock;        // O: awlock,   optional, default: NORMAL
    AXI4_Wr_Cache cache;   // O: awcache,  optional, default: DEVICE_NON_BUFFERABLE
    AXI4_Prot prot;        // O: awprot,   required
    Bit#(4) qos;           // O: awqos,    optional, default: 'b0000
    Bit#(userw) user;      // O: awuser,   optional
} AXI4_Addr_Rq_Wr#(numeric type addrw, numeric type idw, numeric type userw)
    deriving (Bits,Eq);

typedef struct {
    Bit#(dataw) data;            // O: wdata, required
    Bit#(TDiv#(dataw, 8)) strb;  // O: wstrb, optional, default: all 1
    Bit#(1) last;                // O: wlast, required
    Bit#(userw) user;            // O: wuser, optional
} AXI4_Data_Rq_Wr#(numeric type dataw, numeric type userw)
    deriving (Bits,Eq);

typedef struct {
    Bit#(idw) id;     // I: bid,   optional
    AXI4_Resp resp;   // I: bresp, optional
    Bit#(userw) user; // I: buser, optional
} AXI4_Rsp_Wr#(numeric type idw, numeric type userw)
    deriving (Bits,Eq);

endpackage: AXI4Types
