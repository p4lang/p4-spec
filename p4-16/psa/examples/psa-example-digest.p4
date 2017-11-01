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

struct digest_t {
    bit<48> srcAddr;
    bit<9>  ingress_port;
}

struct metadata {
    bit<3>   digest_id;
    digest_t digest_h;
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
                         packed_metadata_in packed_meta,
                         out headers parsed_hdr,
                         inout metadata meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         out psa_parser_output_metadata_t ostd)
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
                        out psa_parser_output_metadata_t ostd)
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
                PacketReplicationEngine pre,
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{

    action do_digest () {
        meta.digest_id = 0;
        meta.digest_h.src_addr = hdr.srcAddr;
        meta.digest_h.ingress_port = istd.ingress_port;
    }
    table mac_cache {
        keys = {
            hdr.srcAddr : exact;
            meta.ingress_port : exact;
        }
        actions = {
            do_digest; nop;
        }
        default_action = do_digest();
    }
    action do_switch (bit<9> egress_port) {
        ostd.egress_port = egress_port;
    }
    table l2_tbl {
        keys = {
            hdr.dstAddr : exact;
        }
        actions = {
            do_switch; nop;
        }
        default_action = nop();
    }
    apply {
        mac_cache.apply();
        l2_tbl.apply();
    }
}


control egress(inout headers hdr,
               inout metadata meta,
               BufferingQueueingEngine bqe,
               in    psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
    apply {

    }
}


control CommonDeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

control IngressDeparserImpl(packet_out packet,
                            digest_out packed_meta,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        if (meta.digest_id == 0) {
            packed_meta.pack(meta.digest_h);
        }
        common_deparser.apply(packet, hdr);
    }
}

control EgressDeparserImpl(packet_out packet,
                           clone_out cl,
                           inout headers hdr,
                           in metadata meta,
                           in psa_egress_output_metadata_t istd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        common_deparser.apply(packet, hdr);
    }
}

PSA_Switch(IngressParserImpl(),
           ingress(),
           IngressDeparserImpl(),
           EgressParserImpl(),
           egress(),
           EgressDeparserImpl()) main;

