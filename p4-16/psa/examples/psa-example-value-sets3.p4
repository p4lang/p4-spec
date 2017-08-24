/*
Copyright 2017 Cisco Systems, Inc.

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

// BEGIN:ValueSet_Example_3
struct CustomValueSet1_t {
    bit<16> etherType;
    bit<8>  partialMacAddress;
}

parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout metadata user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         out psa_parser_output_metadata_t ostd)
{
    ValueSet<CustomValueSet1_t>(2) trill_types;

    state dispatch_tpid_value_set {
        bool is_trill =
            trill_types.is_member({parsed_hdr.ethernet.etherType,
                                   parsed_hdr.ethernet.dstAddr[7:0]});
        transition select(is_trill) {
            true: parse_vlan_tag;
            default: accept;
        }
    }

    // ... etc.
// END:ValueSet_Example_3
    state start {
        buffer.extract(parsed_hdr.ethernet);
        transition select(parsed_hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            0x86DD: parse_ipv6;
            default: dispatch_tpid_value_set;
        }
    }
    state parse_vlan_tag {
        // extract VLAN 802.1Q header here
        transition accept;
    }
    state parse_trill {
        // extract TRILL header here
        transition accept;
    }
    state parse_ipv4 {
        transition accept;
    }
    state parse_ipv6 {
        transition accept;
    }
}

control ingress(inout headers hdr,
                inout metadata user_meta,
                PacketReplicationEngine pre,
                in  psa_ingress_input_metadata_t  istd,
                out psa_ingress_output_metadata_t ostd)
{
    apply {
        ostd.egress_port = 0;
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata user_meta,
                        in psa_egress_parser_input_metadata_t istd,
                        out psa_parser_output_metadata_t ostd)
{
    state start {
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

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

PSA_Switch(IngressParserImpl(),
           ingress(),
           computeChecksum(),
           DeparserImpl(),
           EgressParserImpl(),
           egress(),
           computeChecksum(),
           DeparserImpl()) main;
