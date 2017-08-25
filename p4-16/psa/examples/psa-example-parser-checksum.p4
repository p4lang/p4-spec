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

struct fwd_metadata_t {
}

struct metadata {
    fwd_metadata_t fwd_metadata;
}

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    tcp_t            tcp;
}


// BEGIN:Parse_Error_Example
// Define additional error values, one of them for packets with
// incorrect IPv4 header checksums.
error {
    UnhandledIPv4Options,
    BadIPv4HeaderChecksum
}

typedef bit<32> PacketCounter_t;
typedef bit<8>  ErrorIndex_t;

const bit<9> NUM_ERRORS = 256;

// Action convert_error_to_idx returns a unique ErrorIndex_t value (a
// bit vector) for each possible value of the error type.  The error
// type cannot be directly put into packet headers or used as an index
// into counter, meter, or register arrays, so such a conversion
// 'function' is necessary to get a value that can be used for these
// purposes.

action convert_error_to_idx (in ParserError_t err,
                             out ErrorIndex_t idx)
{
    if (err == error.NoError) {
        idx = 1;
    } else if (err == error.PacketTooShort) {
        idx = 2;
    } else if (err == error.NoMatch) {
        idx = 3;
    } else if (err == error.StackOutOfBounds) {
        idx = 4;
    } else if (err == error.HeaderTooShort) {
        idx = 5;
    } else if (err == error.ParserTimeout) {
        idx = 6;
    } else if (err == error.BadIPv4HeaderChecksum) {
        idx = 7;
    } else if (err == error.UnhandledIPv4Options) {
        idx = 8;
    } else {
        // Unknown error value
        idx = 0;
    }
}

parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout metadata user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         out psa_parser_output_metadata_t ostd)
{
    Checksum<bit<16>>(HashAlgorithm.ones_complement16) ck;
    state start {
        buffer.extract(parsed_hdr.ethernet);
        transition select(parsed_hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        buffer.extract(parsed_hdr.ipv4);
        // TBD: It would be good to enhance this example to
        // demonstrate checking of IPv4 header checksums for IPv4
        // headers with options, but this example does not handle such
        // packets.
        verify(parsed_hdr.ipv4.ihl == 5, error.UnhandledIPv4Options);
        // TBD: Update the code below for checking the IPv4 header
        // checksum with whatever the API we decide upon for a PSA
        // checksum extern.
        ck.clear();
        ck.update({ parsed_hdr.ipv4.version,
                parsed_hdr.ipv4.ihl,
                parsed_hdr.ipv4.diffserv,
                parsed_hdr.ipv4.totalLen,
                parsed_hdr.ipv4.identification,
                parsed_hdr.ipv4.flags,
                parsed_hdr.ipv4.fragOffset,
                parsed_hdr.ipv4.ttl,
                parsed_hdr.ipv4.protocol,
                parsed_hdr.ipv4.hdrChecksum,
                parsed_hdr.ipv4.srcAddr,
                parsed_hdr.ipv4.dstAddr });
        // The verify statement below will cause the parser to enter
        // the reject state, and thus terminate parsing immediately,
        // if the IPv4 header checksum is wrong.  It will also record
        // the error error.BadIPv4HeaderChecksum, which will be
        // available in a metadata field in the ingress control block.
        verify(ck.get() == 0, error.BadIPv4HeaderChecksum);
        transition select(parsed_hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }
    state parse_tcp {
        buffer.extract(parsed_hdr.tcp);
        transition accept;
    }
}

control ingress(inout headers hdr,
                inout metadata user_meta,
                PacketReplicationEngine pre,
                in  psa_ingress_input_metadata_t  istd,
                out psa_ingress_output_metadata_t ostd)
{
    Counter<PacketCounter_t, ErrorIndex_t>
        ((bit<32>) NUM_ERRORS, CounterType_t.packets) parser_error_counts;
    apply {
        if (istd.parser_error != error.NoError) {
            // Example code showing how to count number of times each
            // kind of parser error was seen.
            ErrorIndex_t error_idx;
            convert_error_to_idx(istd.parser_error, error_idx);
            parser_error_counts.count(error_idx);
            ingress_drop(ostd);
            exit;
        }
        // Do normal packet processing here.
    }
}
// END:Parse_Error_Example

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
