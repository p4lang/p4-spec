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

struct fwd_metadata_t {
    bit<32> outport;
}

// BEGIN:Clone_Example_Part1
header clone_i2e_metadata_t {
    bit<8> custom_tag;
    EthernetAddress srcAddr;
}
// END:Clone_Example_Part1

struct metadata {
    fwd_metadata_t fwd_metadata;
    clone_i2e_metadata_t clone_meta;
    bit<3> custom_clone_id;
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
    in psa_ingress_parser_input_metadata_t istd)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

// BEGIN:Clone_Example_Part2
control ingress(inout headers hdr,
                inout metadata user_meta,
                in  psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
    action do_clone (CloneSessionId_t session_id) {
        ostd.clone = true;
        ostd.clone_session_id = session_id;
        user_meta.custom_clone_id = 1;
    }
    table t {
        key = {
            user_meta.fwd_metadata.outport : exact;
        }
        actions = { do_clone; }
    }

    apply {
        t.apply();
    }
}
// END:Clone_Example_Part2

parser EgressParserImpl(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata user_meta,
    in psa_egress_parser_input_metadata_t istd)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
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

control DeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

// BEGIN:Clone_Example_Part3
control IngressDeparserImpl(
    packet_out packet,
    inout headers hdr,
    in metadata meta,
    in psa_ingress_output_metadata_t istd)
{
    DeparserImpl() common_deparser;
    apply {
        common_deparser.apply(packet, hdr);
    }
}

control CloneI2EPackerImpl(
    in headers hdr,
    in metadata meta,
    out clone_i2e_metadata_t clone_i2e_meta)
{
    apply {
        clone_i2e_meta.custom_tag = (bit<8>) meta.custom_clone_id;
        if (meta.custom_clone_id == 1) {
            clone_i2e_meta.srcAddr = hdr.ethernet.srcAddr;
        }
    }
}

control CloneI2EUnpackerImpl(
    in clone_i2e_metadata_t clone_i2e_meta,
    inout metadata meta)
{
    apply {
        meta.clone_meta = clone_i2e_meta;
    }
}
// END:Clone_Example_Part3

control EgressDeparserImpl(
    packet_out packet,
    inout headers hdr,
    in metadata meta,
    in psa_egress_output_metadata_t istd)
{
    DeparserImpl() common_deparser;
    apply {
        common_deparser.apply(packet, hdr);
    }
}

IngressPipeline(
    IngressParserImpl(),
    ingress(),
    IngressDeparserImpl(),
    EmptyNewPacketMetadataInitializer(),
    EmptyResubmitUnpacker(),
    EmptyRecirculateUnpacker(),
    EmptyNormalPacker(),
    EmptyResubmitPacker(),
    CloneI2EPackerImpl(),
    EmptyDigestCreator()) ip;

EgressPipeline(
    EgressParserImpl(),
    egress(),
    EgressDeparserImpl(),
    EmptyNormalUnpacker(),
    CloneI2EUnpackerImpl(),
    EmptyCloneE2EUnpacker(),
    EmptyRecirculatePacker(),
    EmptyCloneE2EPacker()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
