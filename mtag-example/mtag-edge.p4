////////////////////////////////////////////////////////////////
//
// (c) The P4 Language Consortium
//
// P4 Programming Example
//
// Based on the original P4 example in the CCR paper
// http://www.sigcomm.org/ccr/papers/2014/July/0000000.0000004
//
////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////
//
// mtag-edge.p4
//
// This file defines the behavior of the edge switch in an mTag
// example.
//
// The switch is programmed to do local forwarding to a set of
// ports as well as to allow traffic between the local ports
// and a set of uplinks.  Packets on the uplink port are given
// an mTag between the VLAN and IP headers.  Locally switched
// packets should not be mTagged. The program also enforces
// that switching is not allowed between uplink ports.
//
////////////////////////////////////////////////////////////////

#import <stdactions.h>
#import <simple_switch_architecture.h>

// Include the header definitions and parser (with header instances)
#include "headers.p4"
#include "parser.p4"
#include "actions.p4"  // For actions common between edge and agg

#define PORT_COUNT 64  // Total ports in the switch

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
    local bit     error;         // An error in ingress port check

    // Import actions common between edge and aggregation programs
    whitebox common_actions common (
        control_data.copy_to_cpu,
        control_data.cpu_code,
        control_data.drop,

        locals.port_type,
        locals.error
    );

    // Remove the mtag for local processing/switching
    action _strip_mtag() {
        // Strip the tag from the packet...
        remove_header(p.mtag);
        // but keep state that it was mtagged.
        modify_field(p.global_metadata.was_mtagged, 1);
    }

    // Always strip the mtag if present on the edge switch
    table strip_mtag {
        reads {
            p.mtag     : valid; // Was mtag parsed?
        }
        actions {
            _strip_mtag;        // Strip mtag and record metadata
            no_op;              // Pass thru otherwise
        }
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
            no_op;         // Allow packet to continue
        }
        max_size : PORT_COUNT; // One rule per port
    }

    // Action to set the egress port; used for local switching
    action set_egress(in bit<16> egress_spec) {
        modify_field(control_data.egress_spec, egress_spec);
    }

    // Check for "local" switching (not to aggregation layer)
    table local_switching {
        reads {
            p.vlan.vid             : exact;
            p.ipv4.dstAddr         : exact;
        }
        actions {
            set_egress;     // If switched, set egress
            no_op;
        }
    }

    // Add an mTag to the packet; select egress spec based on up1
    action add_mTag(in bit<8> up1, in bit<8> up2,
                    in bit<8> down1, in bit<8> down2)
    {
        add_header(p.mtag);
        // Copy VLAN ethertype to mTag
        modify_field(p.mtag.ethertype, p.vlan.ethertype);

        // Set VLAN's ethertype to signal mTag
        modify_field(p.vlan.ethertype, 0xaaaa);

        // Add the tag source routing information
        modify_field(p.mtag.up1, up1);
        modify_field(p.mtag.up2, up2);
        modify_field(p.mtag.down1, down1);
        modify_field(p.mtag.down2, down2);

        // Set the destination egress port as well from the tag info
        modify_field(control_data.egress_spec, up1);
    }

    // Count packets and bytes by mtag instance added
    blackbox counter pkts_by_dest {
        type : packets;
        direct : mTag_table;
    }

    blackbox counter bytes_by_dest {
        type : bytes;
        direct : mTag_table;
    }

    // Check if the packet needs an mtag and add one if it does.
    table mTag_table {
        reads {
            p.ethernet.dst_addr    : exact;
            p.vlan.vid             : exact;
        }
        actions {
            add_mTag;  // Action called if pkt needs an mtag.
            common.copy_pkt_to_cpu; // Option: If no mtag setup, 
                                      // forward to the CPU
            no_op;
        }
        max_size                 : 20000;
    }

    // The ingress control function
    control main {

        // Always strip mtag if present, save state
        apply(strip_mtag);

        // Identify the source port type
        apply(identify_port);

        // If no error from source_check, continue
        if (locals.error == 0) {
            // Attempt to switch to end hosts
            apply(local_switching);

            // If not locally switched, try to setup mtag
            if (control_data.egress_spec == 0) {
                apply(mTag_table);
            }
         }
    }
}



whitebox_type egress_module (
    inout struct packet_data_t             p,
    in    metadata packet_metadata_t       packet_metadata,
    in    metadata egress_aux_metadata_t   aux_metadata,
    out   metadata egress_pipe_controls_t  control_data,
) {

    // Local metadata declarations
    local bit<4>  port_type;     // Unused in egress
    local bit     error;         // Unused in egress

    local bit<8>  color;         // For metering

    // Import actions common between edge and aggregation programs
    whitebox common_actions common (
        control_data.copy_to_cpu,
        control_data.cpu_code,
        control_data.drop,

        locals.port_type,
        locals.error
    );

    // Packets from agg layer must stay local; enforce that here
    table egress_check {
        reads {
            packet_metadata.ingress_port : exact;
            p.global_metadata.was_mtagged : exact;
        }

        actions {    
            common.drop_pkt;
            no_op;
        }
        max_size : PORT_COUNT; // At most one rule per port
    }

    // Egress metering; this could be direct, but we let SW 
    // use whatever mapping it might like to associate the
    // meter cell with the source/dest pair
    blackbox meter per_dest_by_source {
        type : bytes;
        instance_count : PORT_COUNT * PORT_COUNT;  // Per source/dest pair
    }

    action meter_pkt(in int meter_idx) {
        per_dest_by_source.execute(locals.color, meter_idx);
    }

    // Mark packet color, for uplink ports only
    table egress_meter {
        reads {
            packet_metadata.ingress_port : exact;
            p.mtag.up1 : exact;
        }
        actions {
            meter_pkt;
            no_op;
        }
        size : PORT_COUNT * PORT_COUNT;  // Could be smaller
    }

    // Apply meter policy
    blackbox counter per_color_drops {
        type : packets;
        direct : meter_policy;
    }

    table meter_policy {
        reads {
            locals.color : exact;
        }
        actions {
            drop; // Automatically counted by direct counter above
            no_op;
        }
    }

    // The egress control function
    control main {
        // Check for unknown egress state or bad retagging with mTag.
        apply(egress_check);

        // Apply egress_meter table; if hit, apply meter policy
        apply(egress_meter) {
            hit {
                apply(meter_policy);
            }
        }
    }

}