// If this idea goes forward and becomes part of the official PSA
// specification, then the pseudocode in this file should probably
// become part of the PSA specification, to help explain how things
// should operate.


// The PSA architecture behaves as if the following code was executed
// just before the IngressParser, for all recirculated, resubmitted,
// and new packets from a normal port or from the CPU port:

control JustBeforeIngressParser(
    in psa_ingress_parser_input_metadata_t istd,
    in RESUBM resubmit_meta,
    in RECIRCM recirculate_meta,
    inout M user_meta)
{
    apply {
        switch (istd.packet_path) {
            PSA_PacketPath_t.NORMAL: {
                NewPacketMetadataInitializer(istd.ingress_port, user_meta);
            }
            PSA_PacketPath_t.RESUBMIT: {
                ResubmitUnpacker(resubmit_meta, user_meta);
            }
            PSA_PacketPath_t.RECIRCULATE: {
                RecirculateUnpacker(recirculate_meta, user_meta);
            }
            // Note: For packets about to begin the IngressParser, the
            // cases above exhaust all of the possibilities.  No
            // "default" case is needed.
        }
    }
}

// TBD: Is the IngressDeparser executed once for a packet that is both
// ingress-to-egress cloned and sent normally via unicast or multicast
// to egress?  Or once for the clone, and once for the other copy?
// Does it matter?

control JustAfterIngress(
    in psa_ingress_output_metadata_t ostd,
    in H hdr,   // TBD: Should this be here?
    in M meta,
    out CI2EM clone_i2e_meta,
    out RESUBM resubmit_meta,
    out NM normal_meta)
{
    apply {
        if (ostd.clone) {
            CloneI2EPacker(hdr, meta, clone_i2e_meta);
        }
        if (ostd.drop) {
            // nothing to do here
        } else if (ostd.resubmit) {
            ResubmitPacker(hdr, meta, resubmit_meta);
        } else {
            NormalPacker(hdr, meta, normal_meta);
        }
    }
}

control JustBeforeEgressParser(
    in psa_egress_parser_input_metadata_t istd,
    in NM normal_meta,
    in CI2EM clone_i2e_meta,
    in CE2EM clone_e2e_meta,
    inout M user_meta)
{
    apply {
        switch (istd.packet_path) {
            PSA_PacketPath_t.NORMAL_UNICAST: {
                NormalUnpacker(normal_meta, user_meta);
            }
            PSA_PacketPath_t.NORMAL_MULTICAST: {
                // same as for NORMAL_UNICAST
                NormalUnpacker(normal_meta, user_meta);
            }
            PSA_PacketPath_t.CLONE_I2E: {
                CloneI2EUnpacker(clone_i2e_meta, user_meta);
            }
            PSA_PacketPath_t.CLONE_E2E: {
                CloneE2EUnpacker(clone_e2e_meta, user_meta);
            }
            // Note: For packets about to begin the EgressParser, the
            // cases above exhaust all of the possibilities.  No
            // "default" case is needed.
        }
    }
}

// TBD: Is the EgressDeparser executed once for a packet that is both
// egress-to-egress cloned and sent normally to an output port?  Or
// once for the clone, and once for the other copy?  Does it matter?

control JustAfterEgress(
    in psa_egress_input_metadata_t istd,
    in psa_egress_output_metadata_t ostd,
    in H hdr,   // TBD: Should this be here?
    in M meta,
    out CE2EM clone_e2e_meta,
    out RECIRCM recirculate_meta)
{
    apply {
        if (ostd.clone) {
            CloneE2EPacker(hdr, meta, clone_e2e_meta);
        }
        if (ostd.drop) {
            // nothing to do here
        } else if (istd.egress_port == PSA_PORT_RECIRCULATE) {
            RecirculatePacker(hdr, meta, recirculate_meta);
        } else {
            // Packet is going to an output port.  Nothing to do here.
        }
    }
}

