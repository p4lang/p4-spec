/*
 * SPDX-FileCopyrightText: 2017 Barefoot Networks, Inc.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <core.p4>
/* In a normal PSA program the next line would be:

#include <psa.p4>

 * These examples use psa-for-bmv2.p4 instead so that it is convenient
 * to test compiling these PSA example programs with local changes to
 * the psa-for-bmv2.p4 file. */
#include "psa-for-bmv2.p4"

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

struct empty_metadata_t {
}

struct fwd_metadata_t {
}

struct telemetry_metadata_t {
    bit<8> reason;
}

struct clone_i2e_metadata_t {
    bit<8> clone_tag;
    telemetry_metadata_t telemetry_md;
}

struct metadata {
    fwd_metadata_t fwd_metadata;
    telemetry_metadata_t telemetry_md;
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

// Per PSA spec Section 7.1, ingress packet_path can only be
// NORMAL, RESUBMIT, or RECIRCULATE -- never a clone path.
parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout metadata user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         in empty_metadata_t resubmit_meta,
                         in empty_metadata_t recirculate_meta)
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
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
    action mirror_on_drop(bit<8> reason, CloneSessionId_t session_id) {
        ostd.clone = true;
        ostd.clone_session_id = session_id;
        ostd.drop = true;
        user_meta.telemetry_md.reason = reason;
    }

    // Note: the original example referenced acl_metadata.acl_deny
    // which had no definition in this file.  Using hdr.ipv4.isValid()
    // as a placeholder key until the intended ACL metadata is defined.
    table system_acl {
        key = {
            hdr.ipv4.isValid() : exact;
        }
        actions = { mirror_on_drop; NoAction; }
        default_action = NoAction;
    }

    apply {
        system_acl.apply();
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata user_meta,
                        in psa_egress_parser_input_metadata_t istd,
                        in metadata normal_meta,
                        in clone_i2e_metadata_t clone_i2e_meta,
                        in empty_metadata_t clone_e2e_meta)
{
    CommonParser() p;

    state start {
        p.apply(buffer, parsed_hdr, user_meta);
        transition accept;
    }
}

control egress(inout headers hdr,
               inout metadata user_meta,
               in    psa_egress_input_metadata_t  istd,
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

control IngressDeparserImpl(packet_out packet,
                            out clone_i2e_metadata_t clone_i2e_meta,
                            out empty_metadata_t resubmit_meta,
                            out metadata normal_meta,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() common_deparser;
    apply {
        // user is responsible for constructing the clone header,
        // it may include a user-defined tag to distinguish different
        // clone headers.
        if (psa_clone_i2e(istd)) {
            clone_i2e_meta.clone_tag = 8w1;
            clone_i2e_meta.telemetry_md = meta.telemetry_md;
        }
        if (psa_normal(istd)) {
            normal_meta = meta;
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

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
