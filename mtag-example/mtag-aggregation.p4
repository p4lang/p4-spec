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

#import <stdactions.h>
#import <simple_switch_architecture.h>

// Include the header definitions and parser (with header instances)
#include "headers.p4"
#include "parser.p4"
#include "actions.p4"  // For actions common between edge and agg

// Use the common mtag parser as our main parser module
typedef mtag_parser parser_module;

whitebox_type ingress_module (
    inout struct packet_data_t             p,
    in    metadata packet_metadata_t       packet_metadata,
    in    metadata parser_status_t         parser_status,
    out   metadata ingress_pipe_controls_t control_data,
) {
    
    // Local metadata declarations
    local bit<4>  port_type;     // Type of port: up, down, local...
    local bit     error;         // Unused in aggregation program

    // Import actions common between edge and aggregation programs
    whitebox common_actions common (
        control_data.copy_to_cpu,
        control_data.cpu_code,
        control_data.drop,

        locals.port_type,
        locals.error
    );

    ////////////////////////////////////////////////////////////////

    // Want all packets to have mTag; Apply drop or to-cpu policy  otherwise
    // Will be statically programmed with one entry
    table check_mtag {
        reads {
            p.mtag : valid; // Was mtag parsed?
        }
        actions { // Each table entry specifies *one* action
            common.drop_pkt;           // Deny if policy is to drop
            common.copy_pkt_to_cpu;    // Deny if policy is to go to CPU
            no_op;                     // Accept action
        }
        size : 1;
    }

    ////////////////////////////////////////////////////////////////

    // Identify ingress port: local, up1, up2, down1, down2
    table identify_port {
        reads {
            packet_metadata.ingress_port : exact;
        }
        actions { // Each table entry specifies *one* action
            common.set_port_type;
            common.drop_pkt;        // If unknown port
            no_op;       // Allow packet to continue
        }
        max_size : 64; // One rule per port
    }

    ////////////////////////////////////////////////////////////////

    // Actions to copy the proper field from mtag into the egress spec
    action use_mtag_up1() { // This is actually never used on agg switches
        modify_field(control_data.egress_spec, p.mtag.up1);
    }
    action use_mtag_up2() {
        modify_field(control_data.egress_spec, p.mtag.up2);
    }
    action use_mtag_down1() {
        modify_field(control_data.egress_spec, p.mtag.down1);
    }
    action use_mtag_down2() {
        modify_field(control_data.egress_spec, p.mtag.down2);
    }

    // Table to select output spec from mtag
    table select_output_port {
        reads {
            locals.port_type  : exact; // Up or down, level 1 or 2.
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

    // The ingress control function
    control main {
        // Verify mTag state and port are consistent
        apply(check_mtag);
        apply(identify_port);
        apply(select_output_port);
    }
}

whitebox_type egress_module (
    inout struct packet_data_t             p,
    in    metadata packet_metadata_t       packet_metadata,
    in    metadata egress_aux_metadata_t   aux_metadata,
    out   metadata egress_pipe_controls_t  control_data,
) {
    // No egress functionality needed for this example.
    control main { }
}