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
// UPDATED FOR HYSTERESIS EXAMPLE
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

// Include the header definitions and parser (with header instances)
#include "headers.p4"
#include "parser.p4"
#include "actions.p4"  // For actions marked "common_"

#define PORT_COUNT 64  // Total ports in the switch

////////////////////////////////////////////////////////////////
// Table definitions
////////////////////////////////////////////////////////////////

// Remove the mtag for local processing/switching
action _strip_mtag() {
    // Strip the tag from the packet...
    remove_header(mtag);
    // but keep state that it was mtagged.
    modify_field(local_metadata.was_mtagged, 1);
}

// Always strip the mtag if present on the edge switch
table strip_mtag {
    reads {
        mtag     : valid; // Was mtag parsed?
    }
    actions {
        _strip_mtag;      // Strip mtag and record metadata
        no_op;            // Pass thru otherwise
    }
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
        no_op;         // Allow packet to continue
    }
    max_size : PORT_COUNT; // One rule per port
}

// Action to set the egress port; used for local switching
action set_egress(egress_spec) {
    modify_field(standard_metadata.egress_spec, egress_spec);
}

// Check for "local" switching (not to aggregation layer)
table local_switching {
    reads {
        vlan.vid             : exact;
        ipv4.dstAddr         : exact;
    }
    actions {
        set_egress;     // If switched, set egress
        no_op;
    }
}

// Add an mTag to the packet; select egress spec based on up1
action add_mTag(up1, up2, down1, down2) {
    add_header(mtag);
    // Copy VLAN ethertype to mTag
    modify_field(mtag.ethertype, vlan.ethertype);

    // Set VLAN's ethertype to signal mTag
    modify_field(vlan.ethertype, 0xaaaa);

    // Add the tag source routing information
    modify_field(mtag.up1, up1);
    modify_field(mtag.up2, up2);
    modify_field(mtag.down1, down1);
    modify_field(mtag.down2, down2);

    // Set the destination egress port as well from the tag info
    modify_field(standard_metadata.egress_spec, up1);
}

// Count packets and bytes by mtag instance added
counter pkts_by_dest {
    type : packets;
    direct : mTag_table;
}

counter bytes_by_dest {
    type : bytes;
    direct : mTag_table;
}

// Check if the packet needs an mtag and add one if it does.
table mTag_table {
    reads {
        ethernet.dst_addr    : exact;
        vlan.vid             : exact;
    }
    actions {
        add_mTag;  // Action called if pkt needs an mtag.
        common_copy_pkt_to_cpu; // Option: If no mtag setup, forward to the CPU
        no_op;
    }
    max_size                 : 20000;
}

// Packets from agg layer must stay local; enforce that here
table egress_check {
    reads {
        standard_metadata.ingress_port : exact;
        local_metadata.was_mtagged : exact;
    }

    actions {    
        common_drop_pkt;
        no_op;
    }
    max_size : PORT_COUNT; // At most one rule per port
}

// Egress metering; this could be direct, but we let SW 
// use whatever mapping it might like to associate the
// meter cell with the source/dest pair
meter per_dest_by_source {
    type : bytes;
    instance_count : PORT_COUNT * PORT_COUNT;  // Per source/dest pair
}

// This function updated to track meter index and prev color register
action meter_pkt(meter_idx) {
    // Save index and previous color in metadata; see below.
    modify_field(local_metadata.meter_idx, meter_idx);
    modify_field(local_metadata.prev_color, prev_color[meter_idx]);
    meter(per_dest_by_source, meter_idx, local_metadata.color);
}

// Mark packet color, for uplink ports only
table egress_meter {
    reads {
        standard_metadata.ingress_port : exact;
        mtag.up1 : exact;
    }
    actions {
        meter_pkt;
        no_op;
    }
    size : PORT_COUNT * PORT_COUNT;  // Could be smaller
}

////////////////////////////////////////////////////////////////
// Support added for hysteresis on the meter
//
// Keep the meter's old state in a register. Update the register
// only on transtions => red or => green. Override the meter 
// decision if the register indicates the state was red.
//
////////////////////////////////////////////////////////////////

// The register stores the "previous" state of the color.
// Index is the same as that used by the meter.
register prev_color {
    width : 8;
    instance_count : PORT_COUNT * PORT_COUNT; // paired w/ meters abvoe
}

// Action: Update the color saved in the register
action update_prev_color(new_color) {
    modify_field(prev_color[local_metadata.meter_idx], new_color);
}

// Action: Override packet color with that from the parameter
action mark_pkt(color) {
    modify_field(local_metadata.color, color);
}

//
// This table is statically populated with the following rules:
//    color: green,  prev_color: red    ==> update_prev_color(green)
//    color: red,    prev_color: green  ==> update_prev_color(red)
//    color: yellow, prev_color: red    ==> mark_pkt(red)
// Otherwise, no-op.

table hysteresis_check {
    reads {
        local_metadata.color : exact;
        local_metadata.prev_color : exact;
    }
    actions {
        update_prev_color;
        mark_pkt_red;
        no_op;
    }
    size : 4;
}

// Apply meter policy
counter per_color_drops {
    type : packets;
    direct : meter_policy;
}

// Apply meter policy to the packet based on its color
table meter_policy {
    reads {
        local_metadata.color : exact;
    }
    actions {
        drop; // Automatically counted by direct counter above
        no_op;
    }
}


////////////////////////////////////////////////////////////////
// Control function definitions
////////////////////////////////////////////////////////////////

// The ingress control function
control ingress {

    // Always strip mtag if present, save state
    apply(strip_mtag);

    // Identify the source port type
    apply(identify_port);

    // If no error from source_check, continue
    if (local_metadata.ingress_error == 0) {
        // Attempt to switch to end hosts
        apply(local_switching);

        // If not locally switched, try to setup mtag
        if (standard_metadata.egress_spec == 0) {
            apply(mTag_table);
        }
     }
}

// The egress control function
control egress {
    // Check for unknown egress state or bad retagging with mTag.
    apply(egress_check);
    apply(egress_meter) {
        hit {
            apply(hysteresis_check);
            apply(meter_policy);
        }
    }
}

