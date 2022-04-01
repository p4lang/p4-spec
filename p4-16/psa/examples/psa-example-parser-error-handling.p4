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
/* In a normal PSA program the next line would be:

#include <psa.p4>

 * These examples use psa-for-bmv2.p4 instead so that it is convenient
 * to test compiling these PSA example programs with local changes to
 * the psa-for-bmv2.p4 file. */
#include "psa-for-bmv2.p4"

// This program is very similar in behavior to
// psa-example-parser-checksum.p4, and was originally copied from that
// program and then edited.

// It is intended to demonstrate how to send a copy to the control
// plane of any packet that experiences a parser error, regardless of
// whether that parser error occurred in the ingress parser or egress
// parser.

// At least for packets that experience a parser error in the ingress
// parser, the packet sent to the control plane should be exactly the
// same as the one that arrived at the ingress parser when the parser
// error occurred, prepended by the to_cpu_error_header_t with its
// fields filled in so that the control plane can know as much about
// the packet that experienced the parser error as possible.  It does
// not matter whether the packet might have been resubmitted or
// recirculated in order to cause it to arrive at the ingress parser,
// or arrived there because the packet came from a normal port or the
// CPU port.

// For packets that experience a parser error in the egress parser,
// whether the packet that comes after the to_cpu_error_header_t
// header is identical to the one that arrived at the egress parser
// when the error occurred depends upon the P4 implementation.  See
// the comments in the egress control block for more details.

// Below are the steps taken for packets that experience a parser
// error in the ingress parser:

// (1) The packet is parsed by ingress parser, experiencing a parser
// error.

// (2) The packet is sent to ingress control block with
// istd.parser_error equal to the type of error that occurred.

// (3) ingress control block calls control handle_parser_errors to
// fill in meta.to_cpu_error_hdr.  This entire header is a field in
// the user-defined metadata.  It also drops the ingress packet, and
// sets ostd.clone to true so that an ingress-to-egress clone will be
// created.  It assigns user-defined metadata field clone_reason a
// value of PARSER_ERROR, so that the egress deparser knows why the
// packet should be cloned.  This program does not contain code that
// might make an ingress-to-egress clone for several different
// reasons, but it is written in a way that has comments showing where
// you would extend it to do so.

// (4) the ingress deparser is run, which for cloned packets with
// clone_reason equal to PARSER_ERROR, copies meta.to_cpu_error_hdr
// into a field of clone_i2e_meta that will be carried with the
// original packet to the egress pipeline.

// (5) The egress parser receives the packet with istd.packet_path
// equal to CLONE_I2E, and clone_i2e_meta initialized.  The egress
// parser is written to copy the contents of clone_i2e_meta into a
// user-defined field meta.to_cpu_error_hdr.  It also skips the normal
// packet header parsing, so the packet will be considered all
// payload, no headers.  This prevents any parser errors from
// occurring in the egress parser.  It also assigns meta.clone_reason
// to PARSER_ERROR.

// (6) In the egress control block, packets with meta.clone_reason
// equal to PARSER_ERROR have the user-defined hdr.to_cpu_error_hdr
// copied from the meta.to_cpu_error_hdr, and then exit the egress
// control block to proceed to the egress deparser.

// (7) The egress deparser will receive a packet with packet_path
// NORMAL, because the egress control block did not attempt to create
// a clone, nor drop the packet.  It will emit the contents of
// hdr.to_cpu_error_hdr at the beginning of the output packet, then
// emit as many other headers as are in the program, but all of them
// will be invalid because of the special egress parser case we
// followed for this packet.  Then it will append the payload, which
// is the entire unparsed packet.

// Below are the steps taken for packets that experience a parser
// error in the egress parser:

// (1) packet is parsed by the egress parser, experiencing a parser
// error.

// (2) The packet is sent to egress control block with
// istd.parser_error equal to the type of error that occurred.

// (3) The egress control block will call the same control
// handle_parser_errors mentioned in step (3) of the ingress parser
// error case above, and do the same things.  It also drops the egress
// packet, and sets ostd.clone to true so that an egress-to-egress
// clone will be created.

// (4) The egress deparser is run, which for cloned packets with
// clone_reason equal to PARSER_ERROR, copies meta.to_cpu_error_hdr
// into a field of clone_e2e_meta that will be carried with the packet
// back to the beginning of the egress pipeline.  Unlike step (4) for
// egress, the packet contents are not the packet contents as the
// arrived to the egress parser, but as the rest of the egress
// deparser code emits it.  If that is identical to the packet that
// arrived at the egress parser, good.  Otherwise, the control plane
// will unfortunately not receive a copy of the packet that caused the
// egress parser error, but something different.  C'est la vie.

// The rest of the steps are the same as ingress steps (5) and onwards
// described above.



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

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct empty_metadata_t {
}

struct fwd_metadata_t {
}

// BEGIN:PortId_Annotation_Example
header to_cpu_error_header_t {
    bit<8> error_idx;
    bit<1> ingress;
    bit<3> packet_path;
    bit<4> reserved1;

    // port is ingress_port if ingress is 1, else egress_port

    // Note that no annotation is needed on this or any other values
    // of type `PortIdInHeader_t` or `PortId_t`, because `psa.p4` has
    // an annotation on the `type` definition that the compiler can
    // propagate to all variables of these types.
    PortIdInHeader_t port;
}
// END:PortId_Annotation_Example

enum CloneReason_t {
    NONE,
    PARSER_ERROR
    // Define other clone reasons here
}

struct clone_i2e_metadata_t {
    CloneReason_t clone_reason;
    to_cpu_error_header_t to_cpu_error_hdr;
}

struct clone_e2e_metadata_t {
    CloneReason_t clone_reason;
    to_cpu_error_header_t to_cpu_error_hdr;
}

struct metadata {
    fwd_metadata_t fwd_metadata;
    CloneReason_t clone_reason;
    to_cpu_error_header_t to_cpu_error_hdr;
}

struct headers {
    to_cpu_error_header_t to_cpu_error_hdr;
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    tcp_t            tcp;
}


control packet_path_to_bits(out bit<3> packet_path_bits,
    in PSA_PacketPath_t packet_path)
{
    action set_packet_path_bits(bit<3> bits) {
        packet_path_bits = bits;
    }
    table packet_path_convert {
        key = {
            // Note that P4Runtime v1.0 does not support P4 programs
            // with table search key fields that have any type except
            // one of these:
            //
            // + bit<W>
            // + a serialized enum with a base type of bit<W>
            // + a typedef or type that has a base type of one of the
            //   above.
            //
            // See psa-example-parser-error-handling2.p4 for a variant
            // of this program that avoids this issue using an
            // if-then-elseif daisy chain instead of a table.
            packet_path : exact;
        }
        actions = {
            set_packet_path_bits;
        }
        default_action = set_packet_path_bits(0);
        const entries = {
            PSA_PacketPath_t.NORMAL           : set_packet_path_bits(1);
            PSA_PacketPath_t.NORMAL_UNICAST   : set_packet_path_bits(2);
            PSA_PacketPath_t.NORMAL_MULTICAST : set_packet_path_bits(3);
            PSA_PacketPath_t.CLONE_I2E        : set_packet_path_bits(4);
            PSA_PacketPath_t.CLONE_E2E        : set_packet_path_bits(5);
            PSA_PacketPath_t.RESUBMIT         : set_packet_path_bits(6);
            PSA_PacketPath_t.RECIRCULATE      : set_packet_path_bits(7);
        }
    }
    apply {
        packet_path_convert.apply();
    }
}


// Define additional error values, one of them for packets with
// incorrect IPv4 header checksums.
error {
    UnhandledIPv4Options,
    BadIPv4HeaderChecksum,
    UnknownCloneI2EFormatId,
    UnknownCloneE2EFormatId
}

typedef bit<32> PacketCounter_t;
typedef bit<8>  ErrorIndex_t;

const bit<9> NUM_ERRORS = 256;

parser CommonParser(packet_in buffer,
                    out headers hdr,
                    inout metadata meta)
{
    InternetChecksum() ck;
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        buffer.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        buffer.extract(hdr.ipv4);
        // TBD: It would be good to enhance this example to
        // demonstrate checking of IPv4 header checksums for IPv4
        // headers with options, but this example does not handle such
        // packets.
        verify(hdr.ipv4.ihl == 5, error.UnhandledIPv4Options);
        ck.clear();
        ck.add({
            /* 16-bit word  0   */ hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv,
            /* 16-bit word  1   */ hdr.ipv4.totalLen,
            /* 16-bit word  2   */ hdr.ipv4.identification,
            /* 16-bit word  3   */ hdr.ipv4.flags, hdr.ipv4.fragOffset,
            /* 16-bit word  4   */ hdr.ipv4.ttl, hdr.ipv4.protocol,
            /* 16-bit word  5 skip hdr.ipv4.hdrChecksum, */
            /* 16-bit words 6-7 */ hdr.ipv4.srcAddr,
            /* 16-bit words 8-9 */ hdr.ipv4.dstAddr
            });
        // The verify statement below will cause the parser to enter
        // the reject state, and thus terminate parsing immediately,
        // if the IPv4 header checksum is wrong.  It will also record
        // the error error.BadIPv4HeaderChecksum, which will be
        // available in a metadata field in the ingress control block.
        verify(ck.get() == hdr.ipv4.hdrChecksum,
               error.BadIPv4HeaderChecksum);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }
    state parse_tcp {
        buffer.extract(hdr.tcp);
        transition accept;
    }
}

parser IngressParserImpl(packet_in buffer,
                         out headers hdr,
                         inout metadata meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         in empty_metadata_t resubmit_meta,
                         in empty_metadata_t recirculate_meta)
{
    CommonParser() cp;
    state start {
        transition packet_in_parsing;
    }
    state packet_in_parsing {
        cp.apply(buffer, hdr, meta);
        transition accept;
    }
}

control handle_parser_errors(
    in error parser_error,
    in PSA_PacketPath_t packet_path,
    in PortId_t port,
    out CloneReason_t clone_reason,
    out to_cpu_error_header_t to_cpu_error_hdr)
{
    // Table parser_error_count_and_convert below shows one way to
    // count the number of times each parser error was encountered.
    // Although it is not used in this example program, it also shows
    // how to convert the error value into a unique bit vector value
    // 'error_idx', which can be useful if you wish to put a bit
    // vector encoding of an error into a packet header, e.g. for a
    // packet sent to the control CPU.

    DirectCounter<PacketCounter_t>(PSA_CounterType_t.PACKETS) parser_error_counts;
    ErrorIndex_t error_idx;

    action set_error_idx (ErrorIndex_t idx) {
        error_idx = idx;
        parser_error_counts.count();
    }
    table parser_error_count_and_convert {
        key = {
            // See the comments for table packet_path_convert, which
            // also apply for this table.
            parser_error : exact;
        }
        actions = {
            set_error_idx;
        }
        default_action = set_error_idx(0);
        const entries = {
            error.NoError               : set_error_idx(1);
            error.PacketTooShort        : set_error_idx(2);
            error.NoMatch               : set_error_idx(3);
            error.StackOutOfBounds      : set_error_idx(4);
            error.HeaderTooShort        : set_error_idx(5);
            error.ParserTimeout         : set_error_idx(6);
            error.BadIPv4HeaderChecksum : set_error_idx(7);
            error.UnhandledIPv4Options  : set_error_idx(8);
        }
        psa_direct_counter = parser_error_counts;
    }
    apply {
        // Example code showing how to count number of times each
        // kind of parser error was seen.
        parser_error_count_and_convert.apply();
        // Initialize the contents of an error header to prepend
        // in front of a clone of this packet when sending it to
        // control plane.
        clone_reason = CloneReason_t.PARSER_ERROR;
        to_cpu_error_hdr.setValid();
        to_cpu_error_hdr.error_idx = error_idx;
        packet_path_to_bits.apply(to_cpu_error_hdr.packet_path, packet_path);
        to_cpu_error_hdr.port = psa_PortId_int_to_header(port);
    }
}

control ingress(inout headers hdr,
                inout metadata meta,
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
    apply {
        if (istd.parser_error != error.NoError) {
            // Count number of times each parser error occurred, drop
            // the original packet, and send a clone with a special
            // to-CPU header on it to the control plane, indicating
            // why we are sending this packet to the control plane.
            handle_parser_errors.apply(istd.parser_error,
                istd.packet_path, istd.ingress_port,
                meta.clone_reason, meta.to_cpu_error_hdr);
            meta.to_cpu_error_hdr.ingress = 1;
            ingress_drop(ostd);
            ostd.clone = true;
            ostd.clone_session_id = PSA_CLONE_SESSION_TO_CPU;
            exit;
        }
        // Do normal packet processing here.
    }
}

control CommonDeparserImpl(packet_out packet, inout headers hdr) {
    InternetChecksum() ck;
    apply {
        if (hdr.ipv4.isValid()) {
            ck.add({
                /* 16-bit word  0   */ hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv,
                /* 16-bit word  1   */ hdr.ipv4.totalLen,
                /* 16-bit word  2   */ hdr.ipv4.identification,
                /* 16-bit word  3   */ hdr.ipv4.flags, hdr.ipv4.fragOffset,
                /* 16-bit word  4   */ hdr.ipv4.ttl, hdr.ipv4.protocol,
                /* 16-bit word  5 skip hdr.ipv4.hdrChecksum, */
                /* 16-bit words 6-7 */ hdr.ipv4.srcAddr,
                /* 16-bit words 8-9 */ hdr.ipv4.dstAddr
                });
            hdr.ipv4.hdrChecksum = ck.get();
        }
        // The to_cpu_error_hdr header is only expected to be valid
        // for packets sent from egress processing to the egress
        // deparser, after they were dropped & cloned because a parser
        // error was detected.  It is a header that the control plane
        // will expect to be at the beginning of all packets sent by
        // this P4 program to the control plane.
        packet.emit(hdr.to_cpu_error_hdr);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

control IngressDeparserImpl(packet_out packet,
                            out clone_i2e_metadata_t clone_i2e_meta,
                            out empty_metadata_t resubmit_meta,
                            out empty_metadata_t normal_meta,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() cd;
    apply {
        if (psa_clone_i2e(istd)) {
            clone_i2e_meta.clone_reason = meta.clone_reason;
            if (meta.clone_reason == CloneReason_t.PARSER_ERROR) {
                clone_i2e_meta.to_cpu_error_hdr = meta.to_cpu_error_hdr;
            }
            // If you have other reasons to do CLONE_I2E, with
            // different metadata you want to carry with them, this is
            // where to do the assignments you want.
        }
        cd.apply(packet, hdr);
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers hdr,
                        inout metadata meta,
                        in psa_egress_parser_input_metadata_t istd,
                        in empty_metadata_t normal_meta,
                        in clone_i2e_metadata_t clone_i2e_meta,
                        in clone_e2e_metadata_t clone_e2e_meta)
{
    CommonParser() p;

    state start {
        meta.clone_reason = CloneReason_t.NONE;
        transition select (istd.packet_path) {
            PSA_PacketPath_t.CLONE_I2E: copy_clone_i2e_meta;
            PSA_PacketPath_t.CLONE_E2E: copy_clone_e2e_meta;
            default: packet_in_parsing;
        }
    }
    state copy_clone_i2e_meta {
        transition select (clone_i2e_meta.clone_reason) {
            CloneReason_t.PARSER_ERROR: copy_clone_i2e_meta_parser_error;
            default: clone_i2e_unknown_format_id;
        }
    }
    state copy_clone_i2e_meta_parser_error {
        meta.clone_reason = clone_i2e_meta.clone_reason;
        meta.to_cpu_error_hdr = clone_i2e_meta.to_cpu_error_hdr;
        // Note: We are explicitly choosing _not_ to transition to
        // state packet_in_parsing here.  This is a special case for
        // packets that experienced a parser error.  We don't want to
        // bother going through parsing and encountering an error
        // again.  If we parse exactly 0 bytes for this packet, then
        // the egress deparser should emit 0 bytes for the normal
        // packet headers, and the resulting packet should be
        // identical to the one that arrived at the egress parser.
        transition accept;
    }
    state clone_i2e_unknown_format_id {
        verify(false, error.UnknownCloneI2EFormatId);
    }
    state copy_clone_e2e_meta {
        transition select (clone_i2e_meta.clone_reason) {
            CloneReason_t.PARSER_ERROR: copy_clone_i2e_meta_parser_error;
            default: clone_i2e_unknown_format_id;
        }
    }
    state copy_clone_e2e_meta_parser_error {
        meta.clone_reason = clone_e2e_meta.clone_reason;
        meta.to_cpu_error_hdr = clone_e2e_meta.to_cpu_error_hdr;
        // See comment in copy_clone_i2e_meta_parser_error.
        transition accept;
    }
    state clone_e2e_unknown_format_id {
        verify(false, error.UnknownCloneE2EFormatId);
    }

    state packet_in_parsing {
        p.apply(buffer, hdr, meta);
        transition accept;
    }
}

control egress(inout headers hdr,
               inout metadata meta,
               in    psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
    apply {
        if (meta.clone_reason == CloneReason_t.PARSER_ERROR) {
            // No headers have been parsed in the egress parser, so
            // the entire packet is payload.  Create a header to
            // prepend in front of the packet and send it to the CPU.
            hdr.to_cpu_error_hdr = meta.to_cpu_error_hdr;

            // Note that while this packet was received by the egress
            // pipeline as a result of a clone operation, it is being
            // sent via the PSA "normal" packet path to the CPU port.
            // It will thus go through the normal egress deparser
            // processing, where the hdr.to_cpu_error_hdr will be
            // emitted first, followed by no other valid headers
            // (because we did not parse any headers for packets
            // passing through the 'true' branch of this 'if'
            // statement), followed by the payload, which should be
            // the entire packet as it most recently arrived at the
            // egress parser.
            exit;
        }
        if (istd.parser_error != error.NoError) {
            // Try handling egress parser errors similarly to ingress
            // parser errors.
            //
            // Note: Unlike the ingress case, here the contents of the
            // cloned packet will be that output by the egress
            // deparser when this egress control block is finished, so
            // if this program is running on a P4 implementation where
            // emitting the valid headers that exist after the egress
            // parser encounters an error is _not_ the same as the
            // packet sent into the egress parser, then the control
            // plane will not receive exactly the same packet that
            // caused the parse error.
            handle_parser_errors.apply(istd.parser_error,
                istd.packet_path, istd.egress_port,
                meta.clone_reason, meta.to_cpu_error_hdr);
            meta.to_cpu_error_hdr.ingress = 0;
            egress_drop(ostd);
            ostd.clone = true;
            ostd.clone_session_id = PSA_CLONE_SESSION_TO_CPU;
            exit;
        }
    }
}

control EgressDeparserImpl(packet_out packet,
                           out clone_e2e_metadata_t clone_e2e_meta,
                           out empty_metadata_t recirculate_meta,
                           inout headers hdr,
                           in metadata meta,
                           in psa_egress_output_metadata_t istd,
                           in psa_egress_deparser_input_metadata_t edstd)
{
    CommonDeparserImpl() cd;
    apply {
        if (psa_clone_e2e(istd)) {
            clone_e2e_meta.clone_reason = meta.clone_reason;
            if (meta.clone_reason == CloneReason_t.PARSER_ERROR) {
                clone_e2e_meta.to_cpu_error_hdr = meta.to_cpu_error_hdr;
            }
            // If you have other reasons to do CLONE_E2E with
            // different metadata you want to carry with them, this is
            // where to do the assignments you want.
        }
        cd.apply(packet, hdr);
    }
}

IngressPipeline(IngressParserImpl(),
                ingress(),
                IngressDeparserImpl()) ip;

EgressPipeline(EgressParserImpl(),
               egress(),
               EgressDeparserImpl()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
