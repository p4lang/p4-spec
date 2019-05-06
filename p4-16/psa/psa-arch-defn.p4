// This is a rough draft of a "precise definition" for a P4_16
// architecture.

// This is the PSA architecture, with a not-yet-approved significant
// change proposed here:
// https://github.com/p4lang/p4-spec/pull/757

// Type definitions like PortId_t and others are used below.  They are
// defined in the psa.p4 include file.
#include "psa.p4"

// This type represents an offset from the beginning of a packet, in
// bits.  It is intended to record where the ingress or egress parser
// finished parsing, via some combnation of extract and advance calls.
// Assume that packets are at most 16 Kbytes long, so an offset from
// the start of the packet in bytes must be at least 14 bits long.  An
// arbitrary offset in bits must be at least 17 bits long.

type bit<17> OffsetWithinPacket_t;

// Assume the P4_16 packet_out extern object has been extended with a
// method appendPayload with this signature:

// void appendPayload(packet_in p, OffsetWithinPacket_t offset);

// When called, all bits within packet p starting at the specified
// offset, until the end of p, are appended to the end of the
// packet_out object on which the method is called.

// Also a method initializeToEmptyPacket() that initializes the packet
// to contain nothing:

// void initializeToEmptyPacket();


// All of P4_14, P4_16+v1model, and P4_16+PSA have resubmitted,
// recirculated, and new packets from ports "merged together" for
// ingress processing.  In any actual switch implementation, there is
// likely to be some kind of arbitration, or a packet scheduler, that
// chooses which packet to process in ingress next, when the
// combination of such packets are arriving faster than ingress can
// keep up with.

// The PreIngressPacketScheduler represents such a packet scheduler.
// Implementations could vary widely in the behavior they provide
// here, and also in what kinds of configuration options they provide.

// For example, one implementation might put all such packets into a
// single common FIFO, except for those that are tail dropped when you
// attempt to enqueue them.

// Another implementation might provide per (input port, class of
// service) FIFO queues, where class of service is extracted from a
// packet's 802.1Q header, if the packet has such a header.
// Resubmitted packets have their own separate FIFO queue, as do
// recirculated packets.  There a DRR (Deficit Round Robin) scheduler
// that schedules packets from these many FIFO queues as ingress
// becomes ready to process more packets.

// The PreIngressPacketScheduler extern defined here specifies the
// "inputs" and "outputs", but not the precise internal behavior of a
// particular implementation.

extern PreIngressPacketScheduler<RESUBM, RECIRCM> {
    PreIngressPacketScheduler();
    // Any packets on which enqNewPacket is called, which are later
    // returned by schedulePacket (as opposed to being dropped), will
    // always be returned with the corresponding ingress_port value
    // and packet_path equal to PSA_PacketPath_t.NORMAL.
    void enqNewPacket(
        in packet_in packet,
        in PortId_t ingress_port);
    // Any packets on which enqResubmittedPacket is called, which are
    // later returned by schedulePacket (as opposed to being dropped),
    // will always be returned with the corresponding ingress_port
    // value and packet_path equal to PSA_PacketPath_t.RESUBMIT.
    void enqResubmittedPacket(
        in packet_in packet,
        in PortId_t ingress_port,
        in RESUBM resubmit_meta);
    // Any packets on which enqRecirculatedPacket is called, which are
    // later returned by schedulePacket (as opposed to being dropped),
    // will always be returned with packet_path equal to
    // PSA_PacketPath_t.RECIRCULATE.
    void enqRecirculatedPacket(
        in packet_in packet,
        in RECIRCM recirculate_meta);
    // Every packet that is enqueued using one of the enq methods will
    // either be dropped, or eventually returned exactly once from a
    // call to schedulePacket.  Multiple such packets can be stored
    // within the PreIngressPacketScheduler that are identical in all
    // of their contents and metadata fields, so the storage of the
    // PreIngressPacketScheduler is at least a multiset of packet
    // "objects", and in a real implementation more likely one or more
    // FIFO queues of packet "objects".  There might be only one FIFO
    // queue containing all such packets, or there could be separate
    // queues for each input port, and another for all resubmitted
    // packets, and another for all recirculated packets, etc.
    void schedulePacket(
        out bool packet_valid, // if false, then no packet ready to process
        out PSA_PacketPath_t packet_path,
        out packet_in packet,
        out PortId_t ingress_port,
        out RESUBM resubmit_meta,
        out RECIRCM recirculate_meta);
}

PreIngressPacketScheduler() pips;


// As for the PreIngressPacketScheduler, the PacketReplicationEngine
// could have many details of its behavior that vary from one
// implementation to another, but they should all have a similar
// "interface" as described here.  No attempt is made here to specify
// a control plane interface, except that the interface must have a
// way of configuring clone sessions and multicast groups.  See the
// P4Runtime API specification for one such control plane interface.

extern PacketReplicationEngine<NM, CI2EM, CE2EM> {
    PacketReplicationEngine();

    // Packets stored with enqUnicast will later have packet_path ==
    // PSA_PacketPath_t.NORMAL_UNICAST when scheduled for egress
    // processing.
    void enqUnicast(
        in PortId_t egress_port,
        in ClassOfService_t class_of_service, 
        in packet_out packet_to_send,
        in NM normal_meta);

    // Packets stored with enqMulticast will later have packet_path ==
    // PSA_PacketPath_t.NORMAL_MULTICAST when scheduled for egress
    // processing.
    //
    // The PacketReplicationEngine has internal state, configured by
    // the control plane, such that for each valid multicast_group
    // value the implementation supports, there is a set of
    // (egress_port, instance) pairs.  Except for copies that the
    // implementation may choose to drop, a copy of the packet should
    // later be scheduled for each such (egress_port, instance) pair.
    // All should be identical except in that pair of values.
    void enqMulticast(
        in MulticastGroup_t multicast_group,
        in ClassOfService_t class_of_service, 
        in packet_out packet_to_send,
        in NM normal_meta);
    
    // Packets stored with enqCloneI2E will later have packet_path ==
    // PSA_PacketPath_t.CLONE_I2E when scheduled for egress
    // processing.
    //
    // The PacketReplicationEngine has internal state, configured by
    // the control plane, such that for each valid clone_session_id
    // value the implementation supports, there is a set of
    // (egress_port, instance) pairs.  See enqMulticast notes for
    // packets that should later be scheduled.
    void enqCloneI2E(
        in CloneSessionId_t clone_session_id,
        in packet_out packet_to_send,
        in CI2EM clone_i2e_meta);
    
    // Packets stored with enqCloneE2E will later have packet_path ==
    // PSA_PacketPath_t.CLONE_E2E when scheduled for egress
    // processing.  Otherwise, the same notes for enqCloneI2E apply
    // for enqCloneE2E.
    void enqCloneE2E(
        in CloneSessionId_t clone_session_id,
        in packet_out packet_to_send,
        in CE2EM clone_e2e_meta);

    void schedulePacket(
        out bool packet_valid, // if false, then no packet ready to process
        out PSA_PacketPath_t packet_path,
        out packet_in packet,
        out PortId_t egress_port,
        out ClassOfService_t class_of_service,
        out EgressInstance_t instance,
        out NM normal_meta,
        out CI2EM clone_i2e_meta,
        out CE2EM clone_e2e_meta);
}

PacketReplicationEngine() pre;

extern BufferingQueueingEngine {
    BufferingQueueingEngine();

    // Send a packet to the physical port egress_port.  If there is
    // any notion in the implementation of separate per class of
    // service queueing between egress processing and the port, use
    // class_of_service to select it.
    void enqPacket(
        in PortId_t egress_port,
        in ClassOfService_t class_of_service, 
        in packet_out packet_to_send);
}

// The control NewPacketFromPort is executed whenever a packet is
// received from a port numbered ingress_port, which could be from the
// controller, indicated by (ingress_port == PSA_PORT_CPU).

control NewPacketFromPort(
    in packet_in packet,  // TBD: Does P4_16 allow direction on parameters with type packet_in?
    in PortId_t ingress_port)
{
    apply {
        pips.enqNewPacket(packet, ingress_port);
    }
}

// The control IngressReadyForPacket is executed whenever the ingress
// pipeline is ready to start processing a new packet, at some finite
// rate.

// Note that this description could be broken down more finely, to
// make it more explicit that certain kinds of behaviors are allowed
// for a PSA implementation.

// For example, from reading this description it is not readily
// apparent whether there can be multiple different packets
// concurrently executing IngressReadyForPacket, or not.  The intent
// is that there can be.

// Given that is the intent, it is then not obvious what possible
// execution orders should be permitted, and which should be
// disallowed.  For example, a Tofino implementation would have a
// constant latency from start of Ingress processing until Ingress
// processing is complete, but an NPU implementation could have
// variable latency for Ingress processing, and either enable packets
// from the same input port to be enqueued in the packet buffer in a
// different order than they arrived on the input port, or they could
// have a reordering mechanism that ensures that packets are enqueued
// in the packet buffer in the same relative order they arrived.  Or
// they could have mechanisms where packets in the same "flow" are
// enqueued in the same relative order they arrived, but packets in
// different flows are not constrained in that way.

// It is not clear to me yet whether there are good ways to specify
// such possibilities in code, as opposed to English or other natural
// language.  Certainly such things can be specified in a lot more
// detailed code, e.g. Verilog, but that seems to defeat the purpose
// of having an executable spec that leaves out such details.

control IngressReadyForPacket<IH, IM, NM, CI2EM, RESUBM, RECIRCM>(
    // TBD: any parameters?
    )
{
    bool packet_valid;
    packet_in packet_rcvd;
    PortId_t ingress_port;
    PSA_PacketPath_t packet_path;
    psa_ingress_parser_input_metadata_t igpim;
    psa_ingress_input_metadata_t igim;
    psa_ingress_output_metadata_t igom;
    Timestamp_t ingress_timestamp;
    IH hdr;
    IM meta;
    ParserError_t parser_error;
    OffsetWithinPacket_t parser_final_packet_offset;
    RESUBM resubmit_meta_in;
    NM normal_meta;
    RESUBM resubmit_meta_out;
    RECIRCM recirculate_meta;
    CI2EM clone_i2e_meta;
    bool do_deparsing;
    
    apply {
        pips.schedulePacket(packet_valid, packet_path, packet_rcvd,
            ingress_port, resubmit_meta_in, recirculate_meta);
        if (!packet_valid) {
            // no packets ready to process
            exit;
        }

        // In accordance with P4_16 language specification, any and
        // all members of meta, hdr, and other user-defined types like
        // NM, RESUBM, RECIRCM, and CI2EM that are of type header,
        // header stack, or header_union are all initialized to
        // invalid.

        // Perform implementation-specific initialization of meta
        // and/or hdr here (if any).
        
        // Initialize and/or unpack into meta
        if (packet_path == PSA_PacketPath_t.NORMAL) {
            NewPacketMetadataInitializer.apply(ingress_port, meta);
        } else if (packet_path == PSA_PacketPath_t.RESUBMIT) {
            ResubmitUnpacker.apply(resubmit_meta_in, meta);
        } else { // it must be RECIRCULATE
            RecirculateUnpacker.apply(recirculate_meta, meta);
            ingress_port = PSA_PORT_RECIRCULATE;
        }

        // Initialize ingress parser inputs
        igpim.ingress_port = ingress_port;
        igpim.packet_path = packet_path;
        ingress_timestamp = time_now();
        
        IngressParser.apply(packet_rcvd, hdr, meta, igpim);
        // TBD: Should parser_error be out parameter of parser?  In
        // any case, assume here that somehow the local variable
        // parser_error is assigned the value of any error that
        // occurred during parsing, or error.NoError if no such error
        // occurred.
        parser_error = tbd_error_from_parser_execution;
        parser_final_packet_offset = tbd_number_of_bits_extracted_or_advanced_in_packet_by_parser;

        // Initialize ingress inputs, and at least some of its
        // outputs.
        igim.ingress_port = ingress_port;
        igim.packet_path = packet_path;
        igim.ingress_timestamp = ingress_timestamp;
        igim.parser_error = parser_error;

        igom.class_of_service = 0;
        igom.clone = false;
        igom.clone_session_id = implementation_specific_value_or_garbage;
        igom.drop = true;
        igom.resubmit = false;
        igom.multicast_group = 0;
        igom.egress_port = implementation_specific_value_or_garbage;

        Ingress.apply(hdr, meta, igim, igom);

        // Note that because calling the IngressDeparser can modify
        // the value of its hdr parameter, and because we want to make
        // any calls needed to DigestCreator and Packer controls with
        // the current value of hdr, do not call the deparser unless
        // necessary, and after all such calls to other controls.
        DigestCreator.apply(hdr, meta);
        do_deparsing = false;
        if (igom.clone) {
            CloneI2EPacker.apply(hdr, meta, clone_i2e_meta);
            // packet_rcvd is the original unmodified packet that we
            // began with when this control started.
            pre.enqCloneI2E(igom.clone_session_id, packet_rcvd, clone_i2e_meta);
        }
        if (!tbd_implementation_specific_cos_supported(igom.class_of_service)) {
            // TBD: Recommended to log error about unsupported
            // igom.class_of_service value.
            igom.class_of_service = 0;
        }
        if (igom.drop) {
            // No packet to send for this reason, but check for clone
            // below.
        } else if (igom.resubmit) {
            // An implementation could reuse resubmit_meta_in here if
            // it wishes toto, instead of resubmit_meta_out, but we
            // want to demonstrate an implementation that leaves parts
            // of resubmit_meta_out uninitialized unless the
            // ResubmitPacker explicitly initializes it.
            ResubmitPacker.apply(hdr, meta, resubmit_meta_out);
            // packet_rcvd is the original unmodified packet that we
            // began with when this control started.
            pips.enqResubmittedPacket(packet_rcvd, ingress_port,
                resubmit_meta_out);
        } else if (igom.multicast_group != 0) {
            NormalPacker.apply(hdr, meta, normal_meta);
            do_deparsing = true;
        } else if (platform_port_valid(igom.egress_port)) {
            // see PSA specification's description of
            // platform_port_valid() function.  Its definition is
            // implementation-specific.
            NormalPacker.apply(hdr, meta, normal_meta);
            do_deparsing = true;
        } else {
            // drop the packet
            // TBD: Recommended to log error about unsupported
            // igom.egress_port value.
        }
        if (do_deparsing) {
            packet_to_send.initializeToEmptyPacket();
            IngressDeparser.apply(packet_to_send, hdr, meta, igom);
            // At this point, packet_to_send only contains the
            // contents of headers that were emitted in the ingress
            // deparser.  Now append the unparsed portion of
            // packet_rcvd to it.
            packet_to_send.appendPayload(packet_rcvd,
                parser_final_packet_offset);

            if (igom.multicast_group != 0) {
                pre.enqMulticast(igom.multicast_group, igom.class_of_service,
                    packet_to_send, normal_meta);
            } else {
                pre.enqUnicast(igom.egress_port, igom.class_of_service, 
                    packet_to_send, normal_meta);
            }
        }
    }
}

// The control EgressReadyForPacket is executed whenever the egress
// pipeline is ready to start processing a new packet, at some finite
// rate.

control EgressReadyForPacket<EH, EM, NM, CI2EM, CE2EM, RECIRCM>(
    // TBD: any parameters?
    )
{
    bool packet_valid;
    packet_in packet_rcvd;
    PSA_PacketPath_t packet_path;
    PortId_t egress_port;
    ClassOfService_t class_of_service;
    EgressInstance_t instance;
    psa_egress_parser_input_metadata_t egpim;
    psa_egress_input_metadata_t egim;
    psa_egress_output_metadata_t egom;
    Timestamp_t egress_timestamp;
    EH hdr;
    EM meta;
    ParserError_t parser_error;
    OffsetWithinPacket_t parser_final_packet_offset;
    NM normal_meta;
    CI2EM clone_i2e_meta;
    CE2EM clone_e2e_meta_in;
    CE2EM clone_e2e_meta_out;
    RECIRCM recirculate_meta;
    bool do_deparsing;
    
    apply {
        pre.schedulePacket(packet_valid, packet_path, packet_rcvd, egress_port,
            class_of_service, instance,
            normal_meta, clone_i2e_meta, clone_e2e_meta_in);
        if (!packet_valid) {
            // no packets ready to process
            exit;
        }

        // In accordance with P4_16 language specification, any and
        // all members of meta, hdr, and other user-defined types like
        // NM, CI2EM, CE2EM, and RECIRCM that are of type header,
        // header stack, or header_union are all initialized to
        // invalid.

        // Perform implementation-specific initialization of meta
        // and/or hdr here (if any).

        // Unpack into meta
        if ((packet_path == PSA_PacketPath_t.NORMAL_UNICAST) ||
            (packet_path == PSA_PacketPath_t.NORMAL_MULTICAST))
        {
            NormalUnpacker.apply(normal_meta, meta);
        } else if (packet_path == PSA_PacketPath_t.CLONE_I2E) {
            CloneI2EUnpacker.apply(clone_i2e_meta, meta);
        } else { // it must be CLONE_E2E
            CloneE2EUnpacker.apply(clone_e2e_meta_in, meta);
        }
        if (packet_path == PSA_PacketPath_t.NORMAL_UNICAST) {
            instance = 0;
        }

        // Initialize egress parser inputs
        egpim.egress_port = egress_port;
        egpim.packet_path = packet_path;
        egress_timestamp = time_now();

        EgressParser.apply(packet_rcvd, hdr, meta, egpim);
        // TBD: Should parser_error be out parameter of parser?  In
        // any case, assume here that somehow the local variable
        // parser_error is assigned the value of any error that
        // occurred during parsing, or error.NoError if no such error
        // occurred.
        parser_error = tbd_error_from_parser_execution;
        parser_final_packet_offset = tbd_number_of_bits_extracted_or_advanced_in_packet_by_parser;

        // Initialize egress inputs, and at least some of its outputs.
        egim.class_of_service = class_of_service;
        egim.egress_port = egress_port;
        egim.packet_path = packet_path;
        egim.instance = instance;
        egim.egress_timestamp = egress_timestamp;
        egim.parser_error = parser_error;

        egom.clone = false;
        egom.clone_session_id = implementation_specific_value_or_garbage;
        egom.drop = false;

        Egress.appy(hdr, meta, egim, egom);

        // Note that because calling the EgressDeparser can modify the
        // value of its hdr parameter, and because we want to make any
        // calls needed to Packer controls with the current value of
        // hdr, do not call the deparser unless necessary, and after
        // all such calls to other controls.
        do_deparsing = false;
        if (egom.clone) {
            // An implementation could reuse clone_e2e_meta_in here if
            // it wishes toto, instead of clone_e2e_meta_out, but we
            // want to demonstrate an implementation that leaves parts
            // of clone_e2e_meta_out uninitialized unless the
            // CloneE2EPacker explicitly initializes it.
            CloneE2EPacker.apply(hdr, meta, clone_e2e_meta_out);
            do_deparsing = true;
        }
        if (egom.drop) {
            // No packet to send for this reason, but check for clone
            // below.
            do_deparsing = false;
        } else if (egress_port == PSA_PORT_RECIRCULATE) {
            RecirculatePacker.apply(hdr, meta, recirculate_meta);
            do_deparsing = true;
        } else {
            // send packet to output port in this case
            do_deparsing = true;
        }
        if (do_deparsing) {
            packet_to_send.initializeToEmptyPacket();
            EgressDeparser.apply(packet_to_send, hdr, meta, egom);
            // At this point, packet_to_send only contains the
            // contents of headers that were emitted in the egress
            // deparser.  Now append the unparsed portion of
            // packet_rcvd to it.
            packet_to_send.appendPayload(packet_rcvd,
                parser_final_packet_offset);
            if (egom.clone) {
                pre.enqCloneE2E(egom.clone_session_id, packet_to_send,
                    clone_e2e_meta_out);
            }
            if (egress_port == PSA_PORT_RECIRCULATE) {
                pips.enqRecirculatedPacket(packet_to_send, recirculate_meta);
            } else {
                bqe.enqPacket(egress_port, class_of_service, packet_to_send);
            }
        }
    }
}
