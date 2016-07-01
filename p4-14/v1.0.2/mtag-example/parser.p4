////////////////////////////////////////////////////////////////
//
// (c) The P4 Language Consortium
//
// P4 Programming Example
//
// Based on the original P4 example in the CCR paper
// http://www.sigcomm.org/ccr/papers/2014/July/0000000.0000004
//
// The switch is programmed to do local forwarding to a set of
// ports as well as to allow traffic between the local ports
// and a set of uplinks.  Packets on the uplink port receive
// an mTag between the VLAN and IP headers.  Locally switched
// packets should not be mTagged. The program also enforces
// that switching is not allowed between uplink ports.
//
////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////
// Parser functions and related definitions
////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////
//
// Header instance definitions
//
// Header instances are usually defined with the parser as
// that is where they are initialized.
//
////////////////////////////////////////////////////////////////

header ethernet_t ethernet;
header vlan_t vlan;
header mTag_t mtag;
header ipv4_t ipv4;

// Local metadata instance declaration
metadata local_metadata_t local_metadata;


////////////////////////////////////////////////////////////////
// Parser state machine description
////////////////////////////////////////////////////////////////

// Start with ethernet always.
parser start {
    return ethernet;    
}

parser ethernet {
    extract(ethernet);   // Start with the ethernet header
    return select(latest.ethertype) {
        0x8100:     vlan;
        0x800:      ipv4;
        default:    ingress;
    }
}

parser vlan {
    extract(vlan);
    return select(latest.ethertype) {
        0xaaaa:     mtag;
        0x800:      ipv4;
        default:    ingress;
    }
}

// mTag is allowed after a VLAN tag only
parser mtag {
    extract(mtag);
    return select(latest.ethertype) {
        0x800:      ipv4;
        default:    ingress;
    }
}

parser ipv4 {
    extract(ipv4);
    return ingress;  // All done with parsing; start matching
}
