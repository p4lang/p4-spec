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

}

struct metadata {
    fwd_metadata_t fwd_metadata;
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

parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout metadata user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         out psa_parser_output_metadata_t ostd)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

// clone a packet to CPU.
control ingress(inout headers hdr,
                inout metadata user_meta,
                PacketReplicationEngine pre,
                in  psa_ingress_input_metadata_t  istd,
                out psa_ingress_output_metadata_t ostd)
{
    action do_clone (PortId_t port) {
        ostd.clone = true;
        ostd.clone_port = port;
        ostd.clone_instance = 0;
    }
    table t() {
        key = {
            user_meta : exact;
        }
        actions = { do_clone; }
    }

    apply {
        t.apply();
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata user_meta,
                        in psa_egress_parser_input_metadata_t istd,
                        out psa_parser_output_metadata_t ostd)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

control egress(inout headers hdr,
               inout metadata user_meta,
               BufferingQueueingEngine bqe,
               in  psa_egress_input_metadata_t  istd,
               out psa_egress_output_metadata_t ostd)
{
    apply { }
}

control computeChecksum(inout headers hdr, inout metadata meta) {}


control DeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.ipv4);
    }
}

control IngressDeparserImpl(packet_out packet,
    clone_out clone,
    inout headers hdr,
    in userMetadata meta,
    in psa_ingress_output_metadata_t istd) {
    DeparserImpl() common_deparser;
    apply {
        if (istd.clone_instance == 0 && istd.clone) {
            clone.add_metadata({hdr.eth.srcAddr, hdr.eth.dstAddr});
        }
        if (istd.clone_instance == 1 && istd.clone) {
            clone.add_metadata({hdr.eth.dstAddr, hdr.eth.srcAddr});
        }
        common_deparser.apply(packet, hdr);
    }
}

control EgressDeparserImpl(packet_out packet,
    clone_out clone,
    inout headers hdr,
    in userMetadata meta,
    in psa_egress_output_metadata_t istd) {
    DeparserImpl() common_deparser;
    apply {
        if (istd.clone_instance == 0 && istd.clone) {
            clone.add_metadata({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr});
        }
        common_deparser.apply(packet, hdr);
    }
}

PSA_Switch(IngressParserImpl(),
           ingress(),
           computeChecksum(),
           IngressDeparserImpl(),
           EgressParserImpl(),
           egress(),
           computeChecksum(),
           EgressDeparserImpl()) main;
