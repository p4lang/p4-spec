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

#import <simple_switch_architecture.h>

////////////////////////////////////////////////////////////////
//
// Header instance definitions
//
// Header instances are usually defined with the parser as
// that is where they are initialized.
//
////////////////////////////////////////////////////////////////

struct_type packet_data_t {
    header ethernet_t ethernet;
    header vlan_t vlan;
    header mTag_t mtag;
    header ipv4_t ipv4;

    metadata global_metadata_t global_metadata;    
}

////////////////////////////////////////////////////////////////
// Parser state machine description
////////////////////////////////////////////////////////////////

whitebox_type mtag_parser (
    out struct packet_data_t        p,
    in  metadata packet_metadata_t  packet_metadata
) {

    parser start {
        // Start with ethernet always.
        return p.ethernet;    
    }

    parser ethernet {
        extract(p.ethernet);
        return select(latest.ethertype) {
            0x8100:     vlan;
            0x800:      ipv4;
            default:    accept;
        }
    }

    parser vlan {
        extract(p.vlan);
        return select(latest.ethertype) {
            0xaaaa:     mtag;
            0x800:      ipv4;
            default:    accept;
        }
    }

    // mTag is allowed after a VLAN tag only
    parser mtag {
        extract(p.mtag);
        return select(latest.ethertype) {
            0x800:      ipv4;
            default:    accept;
        }
    }

    parser ipv4 {
        extract(p.ipv4);
        return accept;  // All done with parsing; start matching
    }
}