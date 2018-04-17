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

header header_a_t {
    bit<32> field_a;
}

header header_b_t {
    bit<16> field_b;
    bit<16> field_c;
}

// BEGIN:Resubmit_Example_Part1
struct resubmit_metadata_t {
    bit<8> selector;
    header_a_t header_a;
    header_b_t header_b;
}
// END:Resubmit_Example_Part1

struct empty_metadata_t {}

struct fwd_metadata_t {
    bit<9> output_port;
}

struct metadata {
    resubmit_metadata_t resubmit_meta;
    fwd_metadata_t fwd_meta;
}

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
}

parser CommonParser(packet_in buffer,
    out headers parsed_hdr,
    inout metadata user_meta)
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

parser IngressParserImpl(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata user_meta,
    in psa_ingress_parser_input_metadata_t istd,
    in resubmit_metadata_t resub_meta,
    in empty_metadata_t recirculate_meta)
{
    CommonParser() cp;

    state start {
        transition select(istd.packet_path) {
           PSA_PacketPath_t.RESUBMIT: copy_resubmit_meta;
           PSA_PacketPath_t.NORMAL: packet_in_parsing;
        }
    }

    state copy_resubmit_meta {
        user_meta.resubmit_meta = resub_meta;
        transition packet_in_parsing;
    }

    state packet_in_parsing {
        cp.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

// BEGIN:Resubmit_Example_Part2
control ingress(inout headers hdr,
    inout metadata user_meta,
    in  psa_ingress_input_metadata_t  istd,
    inout psa_ingress_output_metadata_t ostd)
{
    action do_resubmit (PortId_t port) {
        ostd.resubmit = true;
    }
    table t {
        key = {
            user_meta.fwd_meta.output_port : exact;
        }
        actions = { do_resubmit; NoAction; }
    }

    apply {
        // Note that this example will resubmit all input packets
        // forever, until and unless the PSA implementation drops
        // them.
        t.apply();

        // Note: For a more complete example, there should be
        // assignments to meta.resubmit_meta.selector, and the
        // appropriate one of meta.resubmit_meta.header_a or
        // meta.resubmit_meta.header_b
    }
}
// END:Resubmit_Example_Part2

parser EgressParserImpl(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata user_meta,
    in psa_egress_parser_input_metadata_t istd,
    in empty_metadata_t normal_meta,
    in empty_metadata_t clone_i2e_meta,
    in empty_metadata_t clone_e2e_meta)
{
    CommonParser() cp;
    state start {
        cp.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

control egress(inout headers hdr,
    inout metadata user_meta,
    in  psa_egress_input_metadata_t  istd,
    inout psa_egress_output_metadata_t ostd)
{
    apply { }
}

control CommonDeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

// BEGIN:Resubmit_Example_Part3
control IngressDeparserImpl(
    packet_out packet,
    out empty_metadata_t clone_i2e_meta,
    out resubmit_metadata_t resubmit_meta,
    out empty_metadata_t normal_meta,
    inout headers hdr,
    in metadata meta,
    in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        // Assignments to the out parameter resubmit_meta must be
        // guarded by this if condition:
        if (psa_resubmit(istd)) {
            resubmit_meta = meta.resubmit_meta;
        }

        common_deparser.apply(packet, hdr);
    }
}
// END:Resubmit_Example_Part3

control EgressDeparserImpl(
    packet_out packet,
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

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
