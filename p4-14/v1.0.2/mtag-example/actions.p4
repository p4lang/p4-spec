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

////////////////////////////////////////////////////////////////
// Actions used by tables
////////////////////////////////////////////////////////////////

// Copy the packet to the CPU;
action common_copy_pkt_to_cpu(cpu_code, bad_packet) {
    modify_field(local_metadata.copy_to_cpu, 1);
    modify_field(local_metadata.cpu_code, cpu_code);
    modify_field(local_metadata.bad_packet, bad_packet);
}

// Drop the packet; optionally send to CPU and mark bad
action common_drop_pkt(do_copy, cpu_code, bad_packet) {
    modify_field(local_metadata.copy_to_cpu, do_copy);
    modify_field(local_metadata.cpu_code, cpu_code);
    modify_field(local_metadata.bad_packet, bad_packet);
    drop();
}

// Set the port type; see mtag_port_type. Allow error indication.
action common_set_port_type(port_type, ingress_error) {
    modify_field(local_metadata.port_type, port_type);
    modify_field(local_metadata.ingress_error, ingress_error);
}
