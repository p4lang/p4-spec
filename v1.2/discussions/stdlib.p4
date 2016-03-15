#ifndef _STDLIB_P4_
#define _STDLIB_P4_

struct Version
{
    bit<8> major;
    bit<8> minor;
}
    
const Version P4_LIBRARY_VERSION = { 8w0, 8w1 };
    
error {
    NoError,          // no error
    PacketTooShort,   // not enough bits in packet for extract
    NoMatch,          // match expression has no matches
    EmptyStack,       // reference to .last in an empty header stack
    FullStack,        // reference to .next in a full header stack
    OverwritingHeader // one header is extracted twice
}

extern packet_in {
    void extract<T>(out T hdr);
    // T must be a varbit type.
    void extract<T>(out T variableSizeHeader, in bit<32> sizeInBits);
    // does not advance the cursor
    T lookahead<T>();
}
    
extern packet_out {
    void emit<T>(in T hdr);
}

extern void assert(in bool check, in error toSignal); 

action NoAction() {}

match_kind {
    exact,
    ternary,
    lpm,
    range            
}
#endif
