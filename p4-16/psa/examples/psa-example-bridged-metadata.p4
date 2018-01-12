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

struct foo_t {
    bit<7> x;
}

struct my_custom_metadata1_t {
    // whatever you want here, including things that cannot be emitted
    // or parsed, such as values with type enum, values with type
    // error, booleans, etc.  It could also contain structs, headers,
    // header stacks, header unions, stacks of header unions, etc.  At
    // least, the P4_16 language allows these to appear in structs.
    // Some targets may limit your options to a subset of those
    // allowed by the language.

    foo_t foo;
    bool bar;
    error parse_error;
    ethernet_t ether;
    ipv4_t[2] two_ip_hdrs;
}

struct my_custom_metadata2_t {
    // like my_custom_metadata1_t
}

struct my_custom_metadata3_t {
    // like my_custom_metadata1_t
}

struct my_custom_metadata4_t {
    // like my_custom_metadata1_t
}

struct my_custom_metadata5_t {
    // like my_custom_metadata1_t
}

struct my_custom_metadata6_t {
    // like my_custom_metadata1_t
}

// One could use an enum type for format_id as well, which would avoid
// needing to pick a bit width an numeric encoding for the format_id
// values, but you would then need to choose a name for each enum
// value.

typedef bit<8> clone_i2e_format_t;

struct metadata {
    // you can be more creative with type and field names, of course.
    // Just example code here.
    clone_i2e_format_t clone_i2e_meta_format_id;
    my_custom_metadata1_t my_meta1;
    my_custom_metadata2_t my_meta2;
    my_custom_metadata3_t my_meta3;
    my_custom_metadata4_t my_meta4;
    my_custom_metadata5_t my_meta5;
    my_custom_metadata6_t my_meta6;
}

struct resubmit_metadata_t {
    my_custom_metadata4_t my_meta4;
}

struct recirculate_metadata_t {
    my_custom_metadata2_t my_meta2;
    my_custom_metadata3_t my_meta3;
}

// This example shows one way to support multiple formats for metadata
// carried with CLONE_I2E packets.  It does not use an explicit union.
// There is currently no union type in P4_16 that can hold arbitrary
// value types.  You could use a header_union, but then you would be
// restricted to carrying fields that can be put into a header,
// i.e. only bit<W> int<W> and varbit<W> types.

// In this example, we are using a struct with all fields that are
// carried in any of the formats.  This allows arbitrary type fields
// to be carried, but may be more difficult, if it is even possible,
// for a compiler to determine that they can be implemented as a union
// in the implementation.

struct clone_i2e_metadata_t {
    clone_i2e_format_t format_id;
    my_custom_metadata1_t my_meta1;
    my_custom_metadata2_t my_meta2;
    my_custom_metadata3_t my_meta3;
    my_custom_metadata5_t my_meta5;
    my_custom_metadata6_t my_meta6;
}

struct clone_e2e_metadata_t {
    my_custom_metadata2_t my_meta2;
    my_custom_metadata5_t my_meta5;
}

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
}

error {
    UnknownCloneI2EFormatId
}

parser CommonParser(packet_in buffer,
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

parser IngressParserImpl(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata meta,
    in psa_ingress_parser_input_metadata_t istd,
    in resubmit_metadata_t resubmit_meta,
    in recirculate_metadata_t recirculate_meta)
{
    CommonParser() p;

    state start {
        transition select (istd.packet_path) {
            PSA_PacketPath_t.RESUBMIT: copy_resubmit_meta;
            PSA_PacketPath_t.RECIRCULATE: copy_recirculate_meta;
            // No metadata to copy for packets received from port,
            // whether a front panel port or the port from the CPU.
            default: packet_in_parsing;
        }
    }
    state copy_resubmit_meta {
        meta.my_meta4 = resubmit_meta.my_meta4;
        transition packet_in_parsing;
    }
    state copy_recirculate_meta {
        meta.my_meta2 = recirculate_meta.my_meta2;
        meta.my_meta3 = recirculate_meta.my_meta3;
        transition packet_in_parsing;
    }

    state packet_in_parsing {
        p.apply(buffer, parsed_hdr, meta);
        transition accept;
    }
}

parser EgressParserImpl(
    packet_in buffer,
    out headers parsed_hdr,
    inout metadata meta,
    in psa_egress_parser_input_metadata_t istd,
    in metadata normal_meta,
    in clone_i2e_metadata_t clone_i2e_meta,
    in clone_e2e_metadata_t clone_e2e_meta)
{
    CommonParser() p;

    state start {
        transition select (istd.packet_path) {
            PSA_PacketPath_t.CLONE_I2E: copy_clone_i2e_meta;
            PSA_PacketPath_t.CLONE_E2E: copy_clone_e2e_meta;
            default: copy_normal_meta;
        }
    }
    state copy_clone_i2e_meta {
        transition select (clone_i2e_meta.format_id) {
            0: copy_clone_i2e_meta_format_0;
            1: copy_clone_i2e_meta_format_1;
            2: copy_clone_i2e_meta_format_2;
            default: clone_i2e_unknown_format_id;
        }
    }
    state copy_clone_i2e_meta_format_0 {
        meta.my_meta2 = clone_i2e_meta.my_meta2;
        meta.my_meta5 = clone_i2e_meta.my_meta5;
        transition packet_in_parsing;
    }
    state copy_clone_i2e_meta_format_1 {
        meta.my_meta6 = clone_i2e_meta.my_meta6;
        transition packet_in_parsing;
    }
    state copy_clone_i2e_meta_format_2 {
        meta.my_meta5 = clone_i2e_meta.my_meta5;
        meta.my_meta1 = clone_i2e_meta.my_meta1;
        meta.my_meta3 = clone_i2e_meta.my_meta3;
        transition packet_in_parsing;
    }
    state clone_i2e_unknown_format_id {
        verify(false, error.UnknownCloneI2EFormatId);
    }
    state copy_clone_e2e_meta {
        meta.my_meta2 = clone_e2e_meta.my_meta2;
        meta.my_meta5 = clone_e2e_meta.my_meta5;
        transition packet_in_parsing;
    }
    state copy_normal_meta {
        meta = normal_meta;
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
    apply {
        // ... ingress code here ...
    }
}

control egress(inout headers hdr,
               inout metadata meta,
               in    psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
    apply {
        // ... egress code here ...
    }
}

control CommonDeparserImpl(packet_out packet, inout headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

control IngressDeparserImpl(
    packet_out packet,
    out clone_i2e_metadata_t clone_i2e_meta,
    out resubmit_metadata_t resubmit_meta,
    out metadata normal_meta,
    inout headers hdr,
    in metadata meta,
    in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        // Assignments to the out parameter clone_i2e_meta must be
        // guarded by this if condition:
        if (psa_clone_i2e(istd)) {
            clone_i2e_meta.format_id = meta.clone_i2e_meta_format_id;
            if (meta.clone_i2e_meta_format_id == 0) {
                clone_i2e_meta.my_meta2 = meta.my_meta2;
                clone_i2e_meta.my_meta5 = meta.my_meta5;
            } else if (meta.clone_i2e_meta_format_id == 1) {
                clone_i2e_meta.my_meta6 = meta.my_meta6;
            } else if (meta.clone_i2e_meta_format_id == 2) {
                clone_i2e_meta.my_meta5 = meta.my_meta5;
                clone_i2e_meta.my_meta1 = meta.my_meta1;
                clone_i2e_meta.my_meta3 = meta.my_meta3;
            }
        }

        // Assignments to the out parameter resubmit_meta must be
        // guarded by this if condition:
        if (psa_resubmit(istd)) {
            resubmit_meta.my_meta4 = meta.my_meta4;
        }

        // Assignments to the out parameter normal_meta must be
        // guarded by this if condition:
        if (psa_normal(istd)) {
            normal_meta = meta;
        }

        common_deparser.apply(packet, hdr);
    }
}

control EgressDeparserImpl(
    packet_out packet,
    out clone_e2e_metadata_t clone_e2e_meta,
    out recirculate_metadata_t recirculate_meta,
    inout headers hdr,
    in metadata meta,
    in psa_egress_output_metadata_t istd,
    in psa_egress_deparser_input_metadata_t edstd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        // Assignments to the out parameter clone_e2e_meta must be
        // guarded by this if condition:
        if (psa_clone_e2e(istd)) {
            // Metadata to be carried along with CLONE_E2E packets.
            clone_e2e_meta.my_meta2 = meta.my_meta2;
            clone_e2e_meta.my_meta5 = meta.my_meta5;
        }

        // Assignments to the out parameter recirculate_meta must be
        // guarded by this if condition:
        if (psa_recirculate(istd, edstd)) {
            recirculate_meta.my_meta2 = meta.my_meta2;
            recirculate_meta.my_meta3 = meta.my_meta3;
        }

        // There is no metadata that can be included with normal
        // packets going to the a physical port of the device.  TBD
        // whether there should be a way to do so for packets sent to
        // the CPU port.

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
