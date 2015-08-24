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
// actions.p4
//
// This file defines the common actions that can be exercised by
// either an edge or an aggregation switch. Since both of these
// use mostly the same actions, they are put together into 
// this file.
//
////////////////////////////////////////////////////////////////

#import <stdactions.h>
#import <simple_switch_architecture.h>

////////////////////////////////////////////////////////////////
// Actions used by tables
////////////////////////////////////////////////////////////////

whitebox_type common_actions (
    // Intrinsic metadata signals
    out bit    copy_to_cpu,
    out bit<8> cpu_code,
    out bit    drop,

    out bit<4> port_type,
    out bit    error
) {
    // Copy the packet to the CPU;
    action copy_pkt_to_cpu(in bit<8> new_cpu_code) {
        modify_field(copy_to_cpu, 1);
        modify_field(cpu_code, new_cpu_code);
    }

    // Drop the packet; optionally send to CPU
    action drop_pkt(in bit do_copy, in bit<8> new_cpu_code) {
        modify_field(copy_to_cpu, do_copy);
        modify_field(cpu_code, new_cpu_code);
        modify_field(drop, 1);
    }

    // Set the port type; see mtag_port_type. Allow error indication.
    action set_port_type(in bit<4> new_port_type, in bit new_error) {
        modify_field(port_type, new_port_type);
        modify_field(error, new_error);
    }    
}

