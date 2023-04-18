from enum import Enum

class AXPROT(Enum):
    UNPRIV_SEC_DATA = 0
    PRIV_SEC_DATA = 1
    UNPRIV_NONSEC_DATA = 2
    PRIV_NONSEC_DATA = 3
    UNPRIV_SEC_INSTR = 4
    PRIV_SEC_INSTR = 5
    UNPRIV_NONSEC_INSTR = 6
    PRIV_NONSEC_INSTR = 7

class XRESP(Enum):
    OKAY = 0
    EXOKAY = 1
    SLVERR = 2
    DECERR = 3

class AXBURST(Enum):
    FIXED = 0
    INCR = 1
    WRAP = 2
