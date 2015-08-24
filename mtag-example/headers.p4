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
// Header type definitions
////////////////////////////////////////////////////////////////

// Standard L2 Ethernet header
header_type ethernet_t {
    fields {
        dst_addr        : 48; // width in bits
        src_addr        : 48;
        ethertype       : 16;
    }
}

// Standard VLAN tag
header_type vlan_t {
    fields {
        pcp             : 3;
        cfi             : 1;
        vid             : 12;
        ethertype       : 16;
    }
}

// The special m-tag used to control forwarding through the
// aggregation layer of  data center
header_type mTag_t {
    fields {
        up1             : 8;
        up2             : 8;
        down1           : 8;
        down2           : 8;
        ethertype       : 16;
    }
}

// Standard IPv4 header
header_type ipv4_t {
    fields {
        version         : 4;
        ihl             : 4;
        diffserv        : 8;
        totalLen        : 16;
        identification  : 16;
        flags           : 3;
        fragOffset      : 13;
        ttl             : 8;
        protocol        : 8;
        hdrChecksum     : 16;
        srcAddr         : 32;
        dstAddr         : 32;
        options         : *;  // Variable length options
    }
    length : ihl * 4;
    max_length : 60;
}

// Assume standard metadata from compiler.

// Define local metadata here.
//
// copy_to_cpu is an example of target specific intrinisic metadata
// It has special significance to the target resulting in a
// copy of the packet being forwarded to the management CPU.

header_type local_metadata_t {
    fields {
        cpu_code        : 16; // Code for packet going to CPU
        port_type       : 4;  // Type of port: up, down, local...
        ingress_error   : 1;  // An error in ingress port check
        was_mtagged     : 1;  // Track if pkt was mtagged on ingr
        copy_to_cpu     : 1;  // Special code resulting in copy to CPU
        bad_packet      : 1;  // Other error indication
        color           : 8;  // For metering
    }
}


