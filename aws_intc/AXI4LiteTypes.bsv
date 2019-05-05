// ---------------
// AXI4 Lite Types
// ---------------

package AXI4LiteTypes;

typedef enum { // access permissions (p.71)
    UNPRIV_SECURE_DATA          = 3'b000,
    UNPRIV_SECURE_INSTRUCTION   = 3'b001,
    UNPRIV_INSECURE_DATA        = 3'b010,
    UNPRIV_INSECURE_INSTRUCTION = 3'b011,
    PRIV_SECURE_DATA            = 3'b100,
    PRIV_SECURE_INSTRUCTION     = 3'b101,
    PRIV_INSECURE_DATA          = 3'b110,
    PRIV_INSECURE_INSTRUCTION   = 3'b111
} AXI4_Lite_Prot deriving (Bits,Eq);

typedef enum { // read and write response structure (p.54)
    OKAY   = 2'b00,
    EXOKAY = 2'b01, // note: not supported by axi4 lite
    SLVERR = 2'b10,
    DECERR = 2'b11
} AXI4_Lite_Resp deriving (Bits,Eq);

typedef struct { // read request
    Bit#(addrw) addr;
    AXI4_Lite_Prot prot;
} AXI4_Lite_Rq_Rd#(numeric type addrw) deriving (Bits,Eq);

typedef struct { // read response
    Bit#(dataw) data;
    AXI4_Lite_Resp resp;
} AXI4_Lite_Rsp_Rd#(numeric type dataw) deriving (Bits,Eq);

typedef struct { // write request
    Bit#(addrw) addr;
    AXI4_Lite_Prot prot;
    Bit#(dataw) data;
    Bit#(TDiv#(dataw, 8)) strb;
} AXI4_Lite_Rq_Wr#(numeric type addrw, numeric type dataw) deriving (Bits,Eq);

typedef struct { // write response
    AXI4_Lite_Resp resp;
} AXI4_Lite_Rsp_Wr deriving (Bits,Eq);

endpackage: AXI4LiteTypes
