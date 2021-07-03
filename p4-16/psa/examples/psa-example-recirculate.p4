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

header recirc_metadata_t {
    bit<8> custom_field;
}

struct metadata {
    fwd_metadata_t fwd_metadata;
    bit<3> custom_clone_id;
    recirc_metadata_t recirc_header;
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

control ingress(inout headers hdr,
                inout metadata user_meta,
                in  psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
    action do_recirc (PortId_t port) {
        send_to_port(ostd, PSA_PORT_RECIRCULATE);
    }
    table t {
        key = {
            user_meta.fwd_metadata.outport : exact;
        }
        actions = { do_recirc; }
    }

    apply {
        t.apply();
    }
}

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
    apply {
    }
}

control DeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

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

control RecirculatePackerImpl(
    in headers hdr,  // TBD: Should this be here?
    in metadata meta,
    out recirc_metadata_t recirc_meta)
{
    apply {
        recirc_meta.custom_field = 1;
    }
}

control RecirculateUnpackerImpl(
    in recirc_metadata_t recirc_meta,
    inout metadata meta)
{
    apply {
        meta.recirc_header = recirc_meta;
    }
}

IngressPipeline(
    IngressParserImpl(),
    ingress(),
    IngressDeparserImpl(),
    EmptyNewPacketMetadataInitializer(),
    EmptyResubmitUnpacker(),
    RecirculateUnpackerImpl(),
    EmptyNormalPacker(),
    EmptyResubmitPacker(),
    EmptyCloneI2EPacker(),
    EmptyDigestCreator()) ip;

EgressPipeline(
    EgressParserImpl(),
    egress(),
    EgressDeparserImpl(),
    EmptyNormalUnpacker(),
    EmptyCloneI2EUnpacker(),
    EmptyCloneE2EUnpacker(),
    RecirculatePackerImpl(),
    EmptyCloneE2EPacker()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
