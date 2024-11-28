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

header ipv6_t {
    bit<4>   version;
    bit<8>   trafficClass;
    bit<20>  flowLabel;
    bit<16>  payloadLen;
    bit<8>   nextHdr;
    bit<8>   hopLimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
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

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length_;
    bit<16> checksum;
}

struct empty_metadata_t {
}

struct fwd_metadata_t {
    bit<16> checksum_state;
}

struct metadata {
    fwd_metadata_t fwd_metadata;
}

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    ipv6_t           ipv6;
    tcp_t            tcp;
    udp_t            udp;
}


// Define additional error values, one of them for packets with
// incorrect IPv4 header checksums.
error {
    UnhandledIPv4Options,
    BadIPv4HeaderChecksum
}

// tag::Incremental_Checksum_Parser[]
parser IngressParserImpl(packet_in buffer,
                         out headers hdr,
                         inout metadata user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         in empty_metadata_t resubmit_meta,
                         in empty_metadata_t recirculate_meta)
{
    InternetChecksum() ck;

    state start {
        buffer.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            0x86dd: parse_ipv6;
            default: accept;
        }
    }
    state parse_ipv4 {
        buffer.extract(hdr.ipv4);
        verify(hdr.ipv4.ihl == 5, error.UnhandledIPv4Options);

        // Compare the received IPv4 header checkum against one we
        // calculate from scratch.
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
        verify(hdr.ipv4.hdrChecksum == ck.get(), error.BadIPv4HeaderChecksum);

        // See Note 1
        ck.clear();
        ck.subtract({
            /* 16-bit words 0-1 */ hdr.ipv4.srcAddr,
            /* 16-bit words 2-3 */ hdr.ipv4.dstAddr
        });
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            17: parse_udp;
            default: accept;
        }
    }
    state parse_ipv6 {
        buffer.extract(hdr.ipv6);
        // There is no header checksum for IPv6.
        // See Note 2
        ck.clear();
        ck.subtract({
            /* 16-bit words 0-7  */ hdr.ipv6.srcAddr,
            /* 16-bit words 8-15 */ hdr.ipv6.dstAddr
        });
        transition select(hdr.ipv6.nextHdr) {
            6: parse_tcp;
            17: parse_udp;
            default: accept;
        }
    }
    state parse_tcp {
        buffer.extract(hdr.tcp);
        // Part 2 of incremental update of TCP checksum: Subtract out
        // the contribution of the original TCP header.
        ck.subtract({
                /* TCP 16-bit word 0    */ hdr.tcp.srcPort,
                /* TCP 16-bit word 1    */ hdr.tcp.dstPort,
                /* TCP 16-bit words 2-3 */ hdr.tcp.seqNo,
                /* TCP 16-bit words 4-5 */ hdr.tcp.ackNo,
                /* TCP 16-bit word 6    */ hdr.tcp.dataOffset, hdr.tcp.res,
                                           hdr.tcp.ecn, hdr.tcp.ctrl,
                /* TCP 16-bit word 7    */ hdr.tcp.window,
                /* TCP 16-bit word 8    */ hdr.tcp.checksum,
                /* TCP 16-bit word 9    */ hdr.tcp.urgentPtr
            });
        user_meta.fwd_metadata.checksum_state = ck.get_state();
        transition accept;
    }
    state parse_udp {
        buffer.extract(hdr.udp);
        // Part 2 of incremental update of UDP checksum: Subtract out
        // the contribution of the original UDP header.
        ck.subtract({
                /* UDP 16-bit word 0 */ hdr.udp.srcPort,
                /* UDP 16-bit word 1 */ hdr.udp.dstPort,
                /* UDP 16-bit word 2 */ hdr.udp.length_,
                /* UDP 16-bit word 3 */ hdr.udp.checksum
            });
        user_meta.fwd_metadata.checksum_state = ck.get_state();
        transition accept;
    }
}
// end::Incremental_Checksum_Parser[]

// Note 1: regarding parser state parse_ipv4

// Part 1 of incremental update of TCP or UDP checksums, if the TCP or
// UDP packet has an IPv4 header: Subtract out the contribution of the
// IPv4 'pseudo header' fields that the P4 program might change.

// RFC 768 defines the pseudo header for UDP packets with IPv4
// headers, and RFC 793 defines the pseudo header for TCP packets with
// IPv4 headers.  The contents of the pseudo header are nearly
// identical for both of these cases:

// (1) IPv4 source address
// (2) IPv4 destination address
// (3) A byte containing 0, followed by a byte containing the protocol
//     number (6 for TCP, 17 for UDP).
// (4) 16 bits containing the TCP or UDP length

// In this example program, we will assume that only (1) and (2) might
// change.  (3) cannot change, and this example will not demonstrate
// any cases that can change the size of the payload.  Among other
// situations, the TCP length could change if one wished to write a P4
// program that added or removed TCP options.

// This example assumes that anything in the fixed portion of the TCP
// header (20 bytes long) might be changed in the P4 code, but any TCP
// options will always be left unchanged.

// This example does not handle cases of tunneling IPv4/IPv6 inside of
// IPv4/IPv6.


// Note 2: regarding parser state parse_ipv6

// Part 1 of incremental update of TCP or UDP checksum, if the TCP or
// UDP packet has an IPv6 header: Subtract out the contribution of
// IPv6 'pseudo header' fields that the P4 program might change.

// RFC 2460 defines the pseudo header for both TCP and UDP packets
// with IPv6 headers.  It is very similar to the IPv4 pseudo header.
// The primary difference relevant to this example is that it includes
// the IPv6 source and destination addresses.

// Warning: This program only handles the case where there is a base
// IPv6 header, with no extension headers.  There are several cases of
// IPv6 extension headers for which the IPv6 source and/or destination
// address used in the pseudo header comes from an extension header,
// not from the base header.  This example does not attempt to
// document all of those cases, but to get a flavor for what might be
// involved, you can look at other implementatins of IPv6 pseudo
// headers in Scapy, Wireshark, and the Linux kernel.

// For Scapy, see https://github.com/secdev/scapy, the function named
// in6_chksum.  Cases handled there include using an IPv6 destination
// address from the IPv6 Routing or Segment Routing header, if
// present, and/or using an IPv6 source address from the IPv6
// Destination Options extension header, if present.  No claims are
// made here that these are correct, nor that they are the only
// exceptions to the rule of using the addresses from the base IPv6
// header.


// Note 3: regarding parser state parse_udp, and the incremental
// calculation of the outgoing UDP header checksum in the deparser.

// From RFC 768: "If the computed checksum is zero, it is transmitted
// as all ones [ ... ].  An all zero transmitted checksum value means
// that the transmitter generated no checksum (for debugging or for
// higher level protocols that don't care)."

// For tunnel encapsulations that include UDP headers (e.g. VXLAN), it
// is fairly common for routers to send a UDP header with a checksum
// of 0.  This saves the effort required to compute a checksum over
// the full payload of the tunnel-encapsulated packet.

// This example is written assuming that the value of hdr.udp.checksum
// will not be modified in the P4 program if it was received as 0.  In
// addition, if hdr.udp was originally invalid, but is later made
// valid, hdr.udp.checksum will be initialized to 0.  This allows the
// deparser code to recognize and handle this case.


// tag::Incremental_Checksum_Table[]
control ingress(inout headers hdr,
                inout metadata user_meta,
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd) {
    action drop() {
        ingress_drop(ostd);
    }
    action forward_v4(PortId_t port, bit<32> srcAddr) {
        hdr.ipv4.srcAddr = srcAddr;
        send_to_port(ostd, port);
    }
    table route_v4 {
        key = { hdr.ipv4.dstAddr : lpm; }
        actions = {
            forward_v4;
            drop;
        }
    }
    action forward_v6(PortId_t port, bit<128> srcAddr) {
        hdr.ipv6.srcAddr = srcAddr;
        send_to_port(ostd, port);
    }
    table route_v6 {
        key = { hdr.ipv6.dstAddr : lpm; }
        actions = {
            forward_v6;
            drop;
        }
    }
    apply {
        if (hdr.ipv4.isValid()) {
            route_v4.apply();
        } else if (hdr.ipv6.isValid()) {
            route_v6.apply();
        }
    }
}
// end::Incremental_Checksum_Table[]

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata user_meta,
                        in psa_egress_parser_input_metadata_t istd,
                        in empty_metadata_t normal_meta,
                        in empty_metadata_t clone_i2e_meta,
                        in empty_metadata_t clone_e2e_meta)
{
    state start {
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

control IngressDeparserImpl(packet_out packet,
                            out empty_metadata_t clone_i2e_meta,
                            out empty_metadata_t resubmit_meta,
                            out empty_metadata_t normal_meta,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

// tag::Incremental_Checksum_Example[]
control EgressDeparserImpl(packet_out packet,
                           out empty_metadata_t clone_e2e_meta,
                           out empty_metadata_t recirculate_meta,
                           inout headers hdr,
                           in metadata user_meta,
                           in psa_egress_output_metadata_t istd,
                           in psa_egress_deparser_input_metadata_t edstd)
{
    InternetChecksum() ck;
    apply {
        if (hdr.ipv4.isValid()) {
            // Calculate IPv4 header checksum from scratch.
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
            hdr.ipv4.hdrChecksum = ck.get();
        }

        // There is no IPv6 header checksum

        // TCP/UDP header incremental checksum update.
        // Restore the checksum state partially calculated in the
        // parser.
        ck.set_state(user_meta.fwd_metadata.checksum_state);

        if (hdr.ipv4.isValid()) {
            ck.add({
                /* 16-bit words 0-1 */ hdr.ipv4.srcAddr,
                /* 16-bit words 2-3 */ hdr.ipv4.dstAddr
            });
        }
        if (hdr.ipv6.isValid()) {
            ck.add({
                /* 16-bit words 0-7  */ hdr.ipv6.srcAddr,
                /* 16-bit words 8-15 */ hdr.ipv6.dstAddr
            });
        }
        if (hdr.tcp.isValid()) {
            ck.add({
                /* TCP 16-bit word 0    */ hdr.tcp.srcPort,
                /* TCP 16-bit word 1    */ hdr.tcp.dstPort,
                /* TCP 16-bit words 2-3 */ hdr.tcp.seqNo,
                /* TCP 16-bit words 4-5 */ hdr.tcp.ackNo,
                /* TCP 16-bit word 6    */ hdr.tcp.dataOffset, hdr.tcp.res,
                                           hdr.tcp.ecn, hdr.tcp.ctrl,
                /* TCP 16-bit word 7    */ hdr.tcp.window,
                /* TCP 16-bit word 8 skip hdr.tcp.checksum, */
                /* TCP 16-bit word 9    */ hdr.tcp.urgentPtr
            });
            hdr.tcp.checksum = ck.get();
        }
        if (hdr.udp.isValid()) {
            ck.add({
                /* UDP 16-bit word 0 */ hdr.udp.srcPort,
                /* UDP 16-bit word 1 */ hdr.udp.dstPort,
                /* UDP 16-bit word 2 */ hdr.udp.length_
                /* UDP 16-bit word 3 skip hdr.udp.checksum */
            });

            // See Note 3 - If hdr.udp.checksum was received as 0, we
            // should never change it.  If the calculated checksum is
            // 0, send all 1 bits instead.
            if (hdr.udp.checksum != 0) {
                hdr.udp.checksum = ck.get();
                if (hdr.udp.checksum == 0) {
                    hdr.udp.checksum = 0xffff;
                }
            }
        }

        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}
// end::Incremental_Checksum_Example[]

IngressPipeline(IngressParserImpl(),
                ingress(),
                IngressDeparserImpl()) ip;

EgressPipeline(EgressParserImpl(),
               egress(),
               EgressDeparserImpl()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
