/*
Copyright 2026 The P4 Language Consortium

SPDX-License-Identifier: Apache-2.0
*/

// This example demonstrates the use of Meter and DirectMeter externs
// in PSA, implementing a two-rate three-color marker (RFC 2698) for
// traffic policing.
//
// Traffic policing is a common networking function that limits the
// rate of traffic flows. This example shows:
//
//   (1) An indirect Meter extern used to police traffic per ingress
//       port, dropping RED packets and forwarding GREEN/YELLOW ones.
//
//   (2) A DirectMeter extern attached directly to a table, policing
//       traffic per IPv4 destination prefix with per-entry rate limits.
//
//   (3) Color-aware metering: the color assigned by the port meter is
//       passed to the per-prefix DirectMeter, so a packet already
//       marked RED by the port meter will not be upgraded to GREEN
//       by the per-prefix meter.
//
// Packet processing overview:
//
//   Ingress parser -> ingress control -> ingress deparser
//
//   In ingress control:
//     1. The per-port indirect Meter is executed to get an initial
//        packet color based on port traffic rate.
//     2. If the packet is IPv4, the ipv4_da_lpm table is applied.
//        Each entry has a DirectMeter that refines the color based
//        on per-prefix traffic rate.
//     3. RED packets are dropped. GREEN and YELLOW packets are
//        forwarded to the appropriate output port.
//
// This example uses psa-for-bmv2.p4 instead of psa.p4 so that it
// can be conveniently tested with local changes to psa-for-bmv2.p4.

#include <core.p4>
/* In a normal PSA program the next line would be:

#include <psa.p4>

 * These examples use psa-for-bmv2.p4 instead so that it is convenient
 * to test compiling these PSA example programs with local changes to
 * the psa-for-bmv2.p4 file. */
#include "psa-for-bmv2.p4"

// ---------------------------------------------------------------------------
// Header definitions
// ---------------------------------------------------------------------------

typedef bit<48> EthernetAddress;
typedef bit<32> IPv4Address;

header ethernet_t {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16>         etherType;
}

header ipv4_t {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      diffserv;
    bit<16>     totalLen;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     fragOffset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>     hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}

// ---------------------------------------------------------------------------
// Metadata definitions
// ---------------------------------------------------------------------------

struct empty_metadata_t {
}

struct fwd_metadata_t {
    // Color determined by the per-port indirect meter.
    // Passed to the DirectMeter for color-aware metering.
    PSA_MeterColor_t port_color;
}

struct metadata_t {
    fwd_metadata_t fwd_metadata;
}

struct headers_t {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// Number of ports on the device. Each port has its own meter instance.
const bit<32> NUM_PORTS = 512;

// ---------------------------------------------------------------------------
// Common parser shared between ingress and egress pipelines
// ---------------------------------------------------------------------------

parser CommonParser(
    packet_in        buffer,
    out headers_t    parsed_hdr,
    inout metadata_t user_meta)
{
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        buffer.extract(parsed_hdr.ethernet);
        transition select(parsed_hdr.ethernet.etherType) {
            0x0800  : parse_ipv4;
            default : accept;
        }
    }

    state parse_ipv4 {
        buffer.extract(parsed_hdr.ipv4);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------

parser IngressParserImpl(
    packet_in                              buffer,
    out headers_t                          parsed_hdr,
    inout metadata_t                       user_meta,
    in psa_ingress_parser_input_metadata_t istd,
    in empty_metadata_t                    resubmit_meta,
    in empty_metadata_t                    recirculate_meta)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Ingress control block
//
// Demonstrates:
//   - Indirect Meter: one meter instance per port, used to police
//     aggregate traffic arriving on each port.
//   - DirectMeter: one meter instance per table entry in ipv4_da_lpm,
//     used to police traffic per IPv4 destination prefix.
//   - Color-aware metering: the color from the port meter is passed
//     to the DirectMeter so that packets already marked RED cannot be
//     upgraded to GREEN by a per-prefix meter.
// ---------------------------------------------------------------------------

control ingress(
    inout headers_t                      hdr,
    inout metadata_t                     user_meta,
    in    psa_ingress_input_metadata_t   istd,
    inout psa_ingress_output_metadata_t  ostd)
{
    // Indirect meter: one instance per port.
    // Packets arriving on a port that exceeds its configured rate
    // are marked YELLOW or RED.
    // PSA_MeterType_t.BYTES: the meter measures bytes per second.
    Meter<PortId_t>(NUM_PORTS, PSA_MeterType_t.BYTES) port_meter;

    // Direct meter: one instance per entry in ipv4_da_lpm.
    // Each route entry can have its own rate limit, for example to
    // police traffic destined to a particular customer prefix.
    // PSA_MeterType_t.PACKETS: the meter measures packets per second.
    DirectMeter(PSA_MeterType_t.PACKETS) per_prefix_meter;

    // Action: forward the packet to the given output port and
    // execute the per-prefix DirectMeter in color-aware mode.
    // The color returned by per_prefix_meter takes the existing
    // port_color into account: a packet already RED cannot become
    // GREEN.
    action forward(PortId_t port) {
        // Color-aware execute: pass in the color already assigned
        // by the port meter so this meter cannot upgrade a RED packet.
        PSA_MeterColor_t final_color =
            per_prefix_meter.execute(user_meta.fwd_metadata.port_color);

        if (final_color == PSA_MeterColor_t.RED) {
            ingress_drop(ostd);
        } else {
            send_to_port(ostd, port);
        }
    }

    // Action: drop the packet unconditionally (e.g. no route found).
    action drop() {
        ingress_drop(ostd);
    }

    // LPM table on IPv4 destination address.
    // Each entry owns one DirectMeter instance for per-prefix policing.
    table ipv4_da_lpm {
        key = {
            hdr.ipv4.dstAddr : lpm;
        }

        actions = {
            forward;
            drop;
        }

        default_action = drop;

        // This table owns the per_prefix_meter DirectMeter instance.
        psa_direct_meter = per_prefix_meter;
    }

    apply {
        // Step 1: Execute the per-port indirect meter in color-blind
        // mode to get an initial color for this packet.
        // A port that has been sending too many bytes will cause
        // packets to be marked YELLOW or RED here.
        user_meta.fwd_metadata.port_color =
            port_meter.execute(istd.ingress_port);

        // Step 2: If the packet is RED after the port meter, drop it
        // immediately without consulting the routing table.
        if (user_meta.fwd_metadata.port_color == PSA_MeterColor_t.RED) {
            ingress_drop(ostd);
        } else if (hdr.ipv4.isValid()) {
            // Step 3: For GREEN or YELLOW packets, look up the
            // destination address. The matched entry's DirectMeter
            // will further refine the color in color-aware mode.
            ipv4_da_lpm.apply();
        } else {
            // Step 4: Non-IPv4 packets with a non-RED port color are
            // dropped because there is no forwarding decision for them
            // in this simple example.
            ingress_drop(ostd);
        }
    }
}

// ---------------------------------------------------------------------------
// Egress control block
// ---------------------------------------------------------------------------

control egress(
    inout headers_t                     hdr,
    inout metadata_t                    user_meta,
    in    psa_egress_input_metadata_t   istd,
    inout psa_egress_output_metadata_t  ostd)
{
    // Count egress bytes per port using an indirect Meter so that the
    // egress pipeline can also apply rate limiting if desired.
    // RED packets are dropped here to enforce egress rate limiting.
    Meter<PortId_t>(NUM_PORTS, PSA_MeterType_t.BYTES) port_bytes_out;

    apply {
        // Execute the egress port meter in color-blind mode.
        // Because multicast replication happens before egress
        // processing, this update will occur once for each copy made,
        // which in this example is intentional.
        PSA_MeterColor_t egress_color =
            port_bytes_out.execute(istd.egress_port);

        // Drop egress RED packets to enforce egress rate limiting.
        if (egress_color == PSA_MeterColor_t.RED) {
            egress_drop(ostd);
        }
    }
}

// ---------------------------------------------------------------------------
// Common deparser shared between ingress and egress pipelines
// ---------------------------------------------------------------------------

control CommonDeparserImpl(
    packet_out      packet,
    inout headers_t hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

// ---------------------------------------------------------------------------
// Ingress deparser
// ---------------------------------------------------------------------------

control IngressDeparserImpl(
    packet_out                          buffer,
    out empty_metadata_t                clone_i2e_meta,
    out empty_metadata_t                resubmit_meta,
    out empty_metadata_t                normal_meta,
    inout headers_t                     hdr,
    in metadata_t                       meta,
    in psa_ingress_output_metadata_t    istd)
{
    CommonDeparserImpl() cp;

    apply {
        cp.apply(buffer, hdr);
    }
}

// ---------------------------------------------------------------------------
// Egress deparser
// ---------------------------------------------------------------------------

control EgressDeparserImpl(
    packet_out                               buffer,
    out empty_metadata_t                     clone_e2e_meta,
    out empty_metadata_t                     recirculate_meta,
    inout headers_t                          hdr,
    in metadata_t                            meta,
    in psa_egress_output_metadata_t          istd,
    in psa_egress_deparser_input_metadata_t  edstd)
{
    CommonDeparserImpl() cp;

    apply {
        cp.apply(buffer, hdr);
    }
}

// ---------------------------------------------------------------------------
// Egress parser
// ---------------------------------------------------------------------------

parser EgressParserImpl(
    packet_in                              buffer,
    out headers_t                          parsed_hdr,
    inout metadata_t                       user_meta,
    in psa_egress_parser_input_metadata_t  istd,
    in empty_metadata_t                    normal_meta,
    in empty_metadata_t                    clone_i2e_meta,
    in empty_metadata_t                    clone_e2e_meta)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Package instantiation
// ---------------------------------------------------------------------------

IngressPipeline(IngressParserImpl(),
                ingress(),
                IngressDeparserImpl()) ip;

EgressPipeline(EgressParserImpl(),
               egress(),
               EgressDeparserImpl()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep,
           BufferingQueueingEngine()) main;
