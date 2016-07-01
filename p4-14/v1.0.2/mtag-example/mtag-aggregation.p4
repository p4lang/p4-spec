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
//
// mtag-aggregation.p4
//
// This file defines the behavior of the aggregation switch in an
// mTag example.
//
// The switch is programmed to do forwarding strictly based
// on the mTag header. Recall there are two layers of aggregation
// in this example. Both layers use the same program. It is up
// to the application layer to determine where in the
// aggregation layer the switch is.
//
////////////////////////////////////////////////////////////////

// Include the header definitions and parser (with header instances)
#include "headers.p4"
#include "parser.p4"
#include "actions.p4"  // For actions marked "common_"


// Want all packets to have mTag; Apply drop or to-cpu policy  otherwise
// Will be statically programmed with one entry
table check_mtag {
    reads {
        mtag : valid; // Was mtag parsed?
    }
    actions { // Each table entry specifies *one* action
        common_drop_pkt;           // Deny if policy is to drop
        common_copy_pkt_to_cpu;    // Deny if policy is to go to CPU
        no_op;                     // Accept action
    }
    size : 1;
}

////////////////////////////////////////////////////////////////

// Identify ingress port: local, up1, up2, down1, down2
table identify_port {
    reads {
        standard_metadata.ingress_port : exact;
    }
    actions { // Each table entry specifies *one* action
        common_set_port_type;
        common_drop_pkt;        // If unknown port
        no_op;       // Allow packet to continue
    }
    max_size : 64; // One rule per port
}

////////////////////////////////////////////////////////////////

// Actions to copy the proper field from mtag into the egress spec
action use_mtag_up1() { // This is actually never used on agg switches
    modify_field(standard_metadata.egress_spec, mtag.up1);
}
action use_mtag_up2() {
    modify_field(standard_metadata.egress_spec, mtag.up2);
}
action use_mtag_down1() {
    modify_field(standard_metadata.egress_spec, mtag.down1);
}
action use_mtag_down2() {
    modify_field(standard_metadata.egress_spec, mtag.down2);
}

// Table to select output spec from mtag
table select_output_port {
    reads {
        local_metadata.port_type  : exact; // Up or down, level 1 or 2.
    }
    actions {
        use_mtag_up1;
        use_mtag_up2;
        use_mtag_down1;
        use_mtag_down2;
        no_op; // If port type is not recognized, previous policy applied
    }
    max_size : 4; // Only need one entry per port type
}


////////////////////////////////////////////////////////////////
// Control function definitions
////////////////////////////////////////////////////////////////

// The ingress control function
control ingress {
    // Verify mTag state and port are consistent
    apply(check_mtag);
    apply(identify_port);
    apply(select_output_port);
}

// No egress functionality needed for this example.
