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
header clone_metadata_t {
    bit<8> custom_tag;
    EthernetAddress srcAddr;
}
// END:Clone_Example_Part1

struct metadata {
    fwd_metadata_t fwd_metadata;
    clone_metadata_t clone_header;
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

parser CloneParser(packet_in buffer,
                   in psa_ingress_parser_input_metadata_t istd,
                   inout clone_metadata_t clone_meta) {
     state start {
         transition select(buffer.lookahead<bit<8>>()) {
            1 : parse_clone_meta;
            default: reject;
         }
     }
     state parse_clone_meta {
     	 buffer.extract(clone_meta);
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
    CloneParser() cp;

    state start {
        transition select(istd.instance_type) {
           InstanceType_t.CLONE: parse_clone_header;
           InstanceType_t.NORMAL: parse_ethernet;
        }
    }
    
    state parse_clone_header {
        cp.apply(buffer, istd, user_meta.clone_header);
        transition parse_ethernet;
    }

    state parse_ethernet {
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
    action do_clone (PortId_t port) {
        ostd.clone = true;
        ostd.clone_port = port;
        user_meta.custom_clone_id = 3w1;
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
               in  psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
    apply { }
}

control DeparserImpl(packet_out packet, inout headers hdr) {
    apply {
    }
}

// BEGIN:Clone_Example_Part3
control IngressDeparserImpl(packet_out packet,
    clone_out clone,
    inout headers hdr,
    in metadata meta,
    in psa_ingress_output_metadata_t istd) {
    DeparserImpl() common_deparser;
    apply {
        clone_metadata_t clone_md;
        clone_md.srcAddr = hdr.ethernet.srcAddr;
        clone_md.custom_tag = 8w1;
        if (meta.custom_clone_id == 3w1) {
            clone.emit(clone_md);
        }
        common_deparser.apply(packet, hdr);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}
// END:Clone_Example_Part3

control EgressDeparserImpl(packet_out packet,
    clone_out cl,
    inout headers hdr,
    in metadata meta,
    in psa_egress_output_metadata_t istd) {
    DeparserImpl() common_deparser;
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
