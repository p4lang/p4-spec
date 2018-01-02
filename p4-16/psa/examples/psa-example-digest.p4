/*
Copyright 2017 Barefoot Networks, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/**
 * This example implements a simplified MAC-learning switch in a 'reactive'
 * fashion. Whenever a new MAC appears on the switch, a digest is sent to
 * the control plane which 'learn's the new MAC and populates the L2 table
 * with the learned MAC address and its ingress port.
 */

#include <core.p4>
#include "../psa.p4"

typedef bit<48>  EthernetAddress;

header ethernet_t {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16>         etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
}

struct empty_metadata_t {
}

struct mac_learn_digest_t {
    EthernetAddress srcAddr;
    PortId_t        ingress_port;
}

struct metadata {
    bit<3>             digest_id;
    mac_learn_digest_t mac_learn_digest;
}

parser CommonParser(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata meta)
{
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        buffer.extract(parsed_hdr.ethernet);
        transition select(parsed_hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        buffer.extract(parsed_hdr.ipv4);
        transition accept;
    }
}

parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout metadata meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         in empty_metadata_t resubmit_meta,
                         in empty_metadata_t recirculate_meta)
{
    CommonParser() p;

    state start {
        transition packet_in_parsing;
    }

    state packet_in_parsing {
        p.apply(buffer, parsed_hdr, meta);
        transition accept;
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata meta,
                        in psa_egress_parser_input_metadata_t istd,
                        in empty_metadata_t normal_meta,
                        in empty_metadata_t clone_i2e_meta,
                        in empty_metadata_t clone_e2e_meta)
{
    CommonParser() p;

    state start {
        transition packet_in_parsing;
    }

    state packet_in_parsing {
        p.apply(buffer, parsed_hdr, meta);
        transition accept;
    }
}

control ingress(inout headers hdr,
                inout metadata meta,
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
    // This is part of the functionality of a typical Ethernet
    // learning bridge.
    
    // The control plane will typically enter the _same_ keys into the
    // mac_cache and l2_tbl tables.  The entries in l2_tbl are
    // searched for the packet's dest MAC address, and on a hit the
    // resulting action tells where to send the packet.

    // The entries in mac_cache are the same, and the action of every
    // table entry added is NoAction.  If there is a _miss_ in
    // mac_cache, we want to send a message to the control plane
    // software containing the packet's source MAC address, and the
    // port it arrived on.  The control plane should consider creating
    // an entry with that packet's source MAC address into both
    // tables, with the l2_tbl sending future packets out this
    // packet's ingress_port.

    // Typically a learning bridge would 'flood', i.e. when it gets a
    // miss in the l2_tbl, it would send a copy of the packet out of
    // all output ports except the one that it arrived on (and if the
    // bridge had multiple VLANs, it would limit the sending to all
    // ports that are allowed to carry packets for that VLAN).  None
    // of that is implemented in this small example.

    action do_mac_miss () {
        meta.digest_id = 0;
        meta.mac_learn_digest.srcAddr = hdr.ethernet.srcAddr;
        meta.mac_learn_digest.ingress_port = istd.ingress_port;
    }
    table mac_cache {
        key = {
            hdr.ethernet.srcAddr : exact;
        }
        actions = {
            do_mac_miss; NoAction;
        }
        default_action = do_mac_miss();
    }

    action do_switch (PortId_t egress_port) {
        send_to_port(ostd, egress_port);
    }
    table l2_tbl {
        key = {
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            do_switch; NoAction;
        }
        default_action = NoAction();
    }
    apply {
        mac_cache.apply();
        l2_tbl.apply();
    }
}

control egress(inout headers hdr,
               inout metadata meta,
               in    psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
    apply {
    }
}

control CommonDeparserImpl(packet_out packet,
                           inout headers hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

/// Expected control plane API for parsing the digest_out metadata.
control IngressDeparserImpl(packet_out packet,
                            out empty_metadata_t clone_i2e_meta,
                            out empty_metadata_t resubmit_meta,
                            out empty_metadata_t normal_meta,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd)
{
    Digest<mac_learn_digest_t>() digest;
    CommonDeparserImpl() common_deparser;
    apply {
        if (meta.digest_id == 0) {
            digest.pack(meta.mac_learn_digest);
        }
        common_deparser.apply(packet, hdr);
    }
}

control EgressDeparserImpl(packet_out packet,
                           out empty_metadata_t clone_e2e_meta,
                           out empty_metadata_t recirculate_meta,
                           inout headers hdr,
                           in metadata meta,
                           in psa_egress_output_metadata_t istd,
                           in psa_egress_deparser_input_metadata_t edstd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        common_deparser.apply(packet, hdr);
    }
}

IngressPipeline(IngressParserImpl(),
                ingress(),
                IngressDeparserImpl()) ip;

EgressPipeline(EgressParserImpl(),
               egress(),
               EgressDeparserImpl()) ep;

PSA_SWITCH(ip, ep) main;

// A sketch of how the control plane software could look like

/*

struct digest_id_0_t {
    uint64_t srcAddr;
    uint16_t ingress_port;
}

struct digest_id_1_t {
    uint64_t srcAddr;
    uint16_t ingress_port;
    uint32_t metadata;
}

#define RECEIVER_ZERO  0
#define DIGEST_ID_ZERO 0

# register a process to listen to digest from dataplane.
bool digest_receiver_register(RECEIVER_ZERO, DIGEST_ID_ZERO, digest_handler_id_0);
bool digest_receiver_register(RECEIVER_ONE, DIGEST_ID_ONE, digest_handler_id_1);
bool digest_receiver_deregister(RECEIVER_ZERO, DIGEST_ZERO);

// asynchronous handler
bool digest_handler_id_0(digest_id_0_t& digest) {
    fprintf(stderr, "0x%08x %d\n", digest->srcAddr, digest->ingress_port);
}

bool digest_handler_id_1(digest_id_1_t& digest) {
    fprintf(stderr, "0x%08x %d %d\n", digest->srcAddr, digest->ingress_port, digest->metadata);
}

// polling
void process_digest() {
    digest_id_0_t digest_0;
    digest_id_1_t digest_1;
    while(true) {
        if (poll_digest(&digest)) {
            fprintf(stderr, "0x%08x %d\n", digest->srcAddr, digest->ingress_port);
        } else if (poll_digest(&digest_1)) {
            // print
        } else {
            // sleep
        }
    }
}

 */
