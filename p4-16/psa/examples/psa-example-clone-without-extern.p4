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

header clone_0_t {
  bit<16> data;
}

header clone_1_t {
  bit<32> data;
}
    
header_union clone_union_t {
  clone_0_t h0;
  clone_1_t h1;
}

struct clone_metadata_t {
  bit<3> type;
  clone_union_t data;
}

typedef clone_metadata_t CloneMetadata_t;

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

struct metadata {
  fwd_metadata_t fwd_metadata;
  bit<3> custom_clone_id;
  clone_0_t clone_0;
  clone_1_t clone_1;
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

parser CloneParser(in psa_egress_parser_input_metadata_t istd,
                   inout metadata user_meta) {
  state start {
    transition select(istd.clone_metadata.type) {
      0: parse_clone_header_0;
      1: parse_clone_header_1;
      default: reject;
    }
  }
  state parse_clone_header_0 {
    user_meta.custom_clone_id = istd.clone_metadata.type;
    user_meta.clone_0 = istd.clone_metadata.data.h0;
    transition accept;
  }
  state parse_clone_header_1 {
    user_meta.custom_clone_id = istd.clone_metadata.type;
    user_meta.clone_1 = istd.clone_metadata.data.h1;
    transition accept;
  }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout metadata user_meta,
                        in psa_egress_parser_input_metadata_t istd,
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
  state parse_ethernet {
    p.apply(buffer, parsed_hdr, user_meta);
    transition accept;
  }

  state parse_clone_header {
    cp.apply(istd, user_meta);
    transition parse_ethernet;
  }
}

control egress(inout headers hdr,
               inout metadata user_meta,
               in  psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd)
{
  action process_clone_h0 () {
    user_meta.fwd_metadata.outport = (bit<32>)user_meta.clone_0.data;
  }
  action process_clone_h1() {
    user_meta.fwd_metadata.outport = user_meta.clone_1.data;
  }
  table t {
    key = { user_meta.custom_clone_id : exact; }
    actions = { process_clone_h0; process_clone_h1; NoAction; }
    default_action = NoAction();
  }
  apply {
    t.apply();
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
                in  psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd)
{
  action do_clone (PortId_t port) {
    ostd.clone = true;
    ostd.clone_port = port;
    user_meta.custom_clone_id = 3w1;
  }
  table t {
    key = { user_meta.fwd_metadata.outport : exact; }
    actions = { do_clone; NoAction; }
    default_action = NoAction;
  }
  apply {
    t.apply();
  }
}

control IngressDeparserImpl(packet_out packet,
                            inout headers hdr,
                            in metadata meta,
                            in psa_ingress_output_metadata_t istd,
			    out psa_ingress_deparser_output_metadata_t ostd) {
  apply {
    clone_metadata_t clone_md;
    clone_1_t clone_hdr;
    clone_hdr.data = 32w0;
    clone_md.data = clone_hdr ;  //XXX(hanw) how to do assignment on header union?
    clone_md.type = 3w0;
    if (meta.custom_clone_id == 3w1) {
      ostd.clone_metadata = { meta.custom_clone_id, clone_hdr };
    }
    packet.emit(hdr.ethernet);
    packet.emit(hdr.ipv4);
  }
}

control EgressDeparserImpl(packet_out packet,
                           inout headers hdr,
                           in metadata meta,
                           in psa_egress_output_metadata_t istd,
			   out psa_egress_deparser_output_metadata_t ostd) {
  apply {
  }
}

PSA_Switch(IngressParserImpl(),
           ingress(),
           IngressDeparserImpl(),
           EgressParserImpl(),
           egress(),
           EgressDeparserImpl()) main;
