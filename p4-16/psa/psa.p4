/* Copyright 2013-present Barefoot Networks, Inc.

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

#ifndef __PSA_P4__
#define __PSA_P4__

/**
 *   P4-16 declaration of the Portable Switch Architecture
 */

/**********************************************************************
 * Beginning of the part of this target-customized psa.p4 include file
 * that declares data plane widths for one particular target device.
 **********************************************************************/

/* Target device for which this section is customized:
 *
 * This file is only intended for the purpose of including parts of it
 * in the PSA specification document.  It is not intended to be
 * compiled.
 *
 * For examples of psa.p4 include files customized for their P4
 * targets, see p4include/bmv2/psa.p4 and p4include/dpdk/psa.p4 in the
 * https://github.com/p4lang/p4c repository. */
#error "This file is for documentation purposes only and is not intended to be compiled"

// tag::Type_defns[]
/* These are defined using `typedef`, not `type`, so they are truly
 * just different names for the type bit<W> for the particular width W
 * shown.  Unlike the `type` definitions below, values declared with
 * the `typedef` type names can be freely mingled in expressions, just
 * as any value declared with type bit<W> can.  Values declared with
 * one of the `type` names below _cannot_ be so freely mingled, unless
 * you first cast them to the corresponding `typedef` type.  While
 * that may be inconvenient when you need to do arithmetic on such
 * values, it is the price to pay for having all occurrences of values
 * of the `type` types marked as such in the automatically generated
 * control plane API.
 *
 * Note that the width of typedef <name>Uint_t will always be the same
 * as the width of type <name>_t. */
typedef bit<unspecified> PortIdUint_t;
typedef bit<unspecified> MulticastGroupUint_t;
typedef bit<unspecified> CloneSessionIdUint_t;
typedef bit<unspecified> ClassOfServiceUint_t;
typedef bit<unspecified> PacketLengthUint_t;
typedef bit<unspecified> EgressInstanceUint_t;
typedef bit<unspecified> TimestampUint_t;

@p4runtime_translation("p4.org/psa/v1/PortId_t", 32)
type PortIdUint_t         PortId_t;
@p4runtime_translation("p4.org/psa/v1/MulticastGroup_t", 32)
type MulticastGroupUint_t MulticastGroup_t;
@p4runtime_translation("p4.org/psa/v1/CloneSessionId_t", 16)
type CloneSessionIdUint_t CloneSessionId_t;
@p4runtime_translation("p4.org/psa/v1/ClassOfService_t", 8)
type ClassOfServiceUint_t ClassOfService_t;
@p4runtime_translation("p4.org/psa/v1/PacketLength_t", 16)
type PacketLengthUint_t   PacketLength_t;
@p4runtime_translation("p4.org/psa/v1/EgressInstance_t", 16)
type EgressInstanceUint_t EgressInstance_t;
@p4runtime_translation("p4.org/psa/v1/Timestamp_t", 64)
type TimestampUint_t      Timestamp_t;
typedef error   ParserError_t;

const PortId_t PSA_PORT_RECIRCULATE = (PortId_t) unspecified;
const PortId_t PSA_PORT_CPU = (PortId_t) unspecified;

const CloneSessionId_t PSA_CLONE_SESSION_TO_CPU = (CloneSessiontId_t) unspecified;
// end::Type_defns[]

/**********************************************************************
 * End of the part of this target-customized psa.p4 include file that
 * declares data plane widths for one particular target device.
 **********************************************************************/

// tag::Type_defns2[]

/* Note: All of the types with `InHeader` in their name are intended
 * only to carry values of the corresponding types in packet headers
 * between a PSA device and the P4Runtime Server software that manages
 * it.
 *
 * The bit widths here are _independent_ of any particular PSA target
 * device, and should _not_ be customized for each target.
 *
 * The bit widths are intended to be at least as large as any PSA
 * device will ever have for that type.  Thus these types may also be
 * useful to define packet headers that are sent directly between a
 * PSA device and other devices, without going through P4Runtime
 * Server software (e.g. this could be useful for sending packets to a
 * controller or data collection system using higher packet rates than
 * the P4Runtime Server can handle).  If used for this purpose, there
 * is no requirement that the PSA data plane _automatically_ perform
 * the numerical translation of these types that would occur if the
 * header went through the P4Runtime Server.  Any such desired
 * translation is up to the author of the P4 program to perform with
 * explicit code.
 *
 * All widths must be a multiple of 8, so that any subset of these
 * fields may be used in a single P4 header definition, even on P4
 * implementations that restrict headers to contain fields with a
 * total length that is a multiple of 8 bits. */

/* See the comments near the definition of PortIdUint_t for why these
 * typedef definitions exist. */
typedef bit<32> PortIdInHeaderUint_t;
typedef bit<32> MulticastGroupInHeaderUint_t;
typedef bit<16> CloneSessionIdInHeaderUint_t;
typedef bit<8>  ClassOfServiceInHeaderUint_t;
typedef bit<16> PacketLengthInHeaderUint_t;
typedef bit<16> EgressInstanceInHeaderUint_t;
typedef bit<64> TimestampInHeaderUint_t;

@p4runtime_translation("p4.org/psa/v1/PortIdInHeader_t", 32)
type  PortIdInHeaderUint_t         PortIdInHeader_t;
@p4runtime_translation("p4.org/psa/v1/MulticastGroupInHeader_t", 32)
type  MulticastGroupInHeaderUint_t MulticastGroupInHeader_t;
@p4runtime_translation("p4.org/psa/v1/CloneSessionIdInHeader_t", 16)
type  CloneSessionIdInHeaderUint_t CloneSessionIdInHeader_t;
@p4runtime_translation("p4.org/psa/v1/ClassOfServiceInHeader_t", 8)
type  ClassOfServiceInHeaderUint_t ClassOfServiceInHeader_t;
@p4runtime_translation("p4.org/psa/v1/PacketLengthInHeader_t", 16)
type  PacketLengthInHeaderUint_t   PacketLengthInHeader_t;
@p4runtime_translation("p4.org/psa/v1/EgressInstanceInHeader_t", 16)
type  EgressInstanceInHeaderUint_t EgressInstanceInHeader_t;
@p4runtime_translation("p4.org/psa/v1/TimestampInHeader_t", 64)
type  TimestampInHeaderUint_t      TimestampInHeader_t;
// end::Type_defns2[]

/* The _int_to_header functions were written to convert a value of
 * type <name>_t (a value INTernal to the data path) to a value of
 * type <name>InHeader_t inside a header that will be sent to the CPU
 * port.
 *
 * The _header_to_int functions were written to convert values in the
 * opposite direction, typically for assigning a value in a header
 * received from the CPU port, to a value you wish to use in the rest
 * of your code.
 *
 * The reason that three casts are needed is that each of the original
 * and target types is declared via P4_16 'type', so without a cast
 * they can only be assigned to values of that identical type.  The
 * first cast changes it from the original 'type' to a 'bit<W1>' value
 * of the same bit width W1.  The second cast changes its bit width,
 * either prepending 0s if it becomes wider, or discarding the most
 * significant bits if it becomes narrower.  The third cast changes it
 * from a 'bit<W2>' value to the final 'type', with the same width
 * W2. */

PortId_t psa_PortId_header_to_int (in PortIdInHeader_t x) {
    return (PortId_t) (PortIdUint_t) (PortIdInHeaderUint_t) x;
}
MulticastGroup_t psa_MulticastGroup_header_to_int (in MulticastGroupInHeader_t x) {
    return (MulticastGroup_t) (MulticastGroupUint_t) (MulticastGroupInHeaderUint_t) x;
}
CloneSessionId_t psa_CloneSessionId_header_to_int (in CloneSessionIdInHeader_t x) {
    return (CloneSessionId_t) (CloneSessionIdUint_t) (CloneSessionIdInHeaderUint_t) x;
}
ClassOfService_t psa_ClassOfService_header_to_int (in ClassOfServiceInHeader_t x) {
    return (ClassOfService_t) (ClassOfServiceUint_t) (ClassOfServiceInHeaderUint_t) x;
}
PacketLength_t psa_PacketLength_header_to_int (in PacketLengthInHeader_t x) {
    return (PacketLength_t) (PacketLengthUint_t) (PacketLengthInHeaderUint_t) x;
}
EgressInstance_t psa_EgressInstance_header_to_int (in EgressInstanceInHeader_t x) {
    return (EgressInstance_t) (EgressInstanceUint_t) (EgressInstanceInHeaderUint_t) x;
}
Timestamp_t psa_Timestamp_header_to_int (in TimestampInHeader_t x) {
    return (Timestamp_t) (TimestampUint_t) (TimestampInHeaderUint_t) x;
}

PortIdInHeader_t psa_PortId_int_to_header (in PortId_t x) {
    return (PortIdInHeader_t) (PortIdInHeaderUint_t) (PortIdUint_t) x;
}
MulticastGroupInHeader_t psa_MulticastGroup_int_to_header (in MulticastGroup_t x) {
    return (MulticastGroupInHeader_t) (MulticastGroupInHeaderUint_t) (MulticastGroupUint_t) x;
}
CloneSessionIdInHeader_t psa_CloneSessionId_int_to_header (in CloneSessionId_t x) {
    return (CloneSessionIdInHeader_t) (CloneSessionIdInHeaderUint_t) (CloneSessionIdUint_t) x;
}
ClassOfServiceInHeader_t psa_ClassOfService_int_to_header (in ClassOfService_t x) {
    return (ClassOfServiceInHeader_t) (ClassOfServiceInHeaderUint_t) (ClassOfServiceUint_t) x;
}
PacketLengthInHeader_t psa_PacketLength_int_to_header (in PacketLength_t x) {
    return (PacketLengthInHeader_t) (PacketLengthInHeaderUint_t) (PacketLengthUint_t) x;
}
EgressInstanceInHeader_t psa_EgressInstance_int_to_header (in EgressInstance_t x) {
    return (EgressInstanceInHeader_t) (EgressInstanceInHeaderUint_t) (EgressInstanceUint_t) x;
}
TimestampInHeader_t psa_Timestamp_int_to_header (in Timestamp_t x) {
    return (TimestampInHeader_t) (TimestampInHeaderUint_t) (TimestampUint_t) x;
}

// tag::enum_PSA_IdleTimeout_t[]
/// Supported values for the psa_idle_timeout table property
enum PSA_IdleTimeout_t {
    NO_TIMEOUT,
    NOTIFY_CONTROL
};
// end::enum_PSA_IdleTimeout_t[]

// tag::Metadata_types[]
enum PSA_PacketPath_t {
    NORMAL,     /// Packet received by ingress that is none of the cases below.
    NORMAL_UNICAST,   /// Normal packet received by egress which is unicast
    NORMAL_MULTICAST, /// Normal packet received by egress which is multicast
    CLONE_I2E,  /// Packet created via a clone operation in ingress,
                /// destined for egress
    CLONE_E2E,  /// Packet created via a clone operation in egress,
                /// destined for egress
    RESUBMIT,   /// Packet arrival is the result of a resubmit operation
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

struct psa_ingress_parser_input_metadata_t {
  PortId_t                 ingress_port;
  PSA_PacketPath_t         packet_path;
}

struct psa_egress_parser_input_metadata_t {
  PortId_t                 egress_port;
  PSA_PacketPath_t         packet_path;
}

struct psa_ingress_input_metadata_t {
  // All of these values are initialized by the architecture before
  // the Ingress control block begins executing.
  PortId_t                 ingress_port;
  PSA_PacketPath_t         packet_path;
  Timestamp_t              ingress_timestamp;
  ParserError_t            parser_error;
}
// tag::Metadata_ingress_output[]
struct psa_ingress_output_metadata_t {
  // The comment after each field specifies its initial value when the
  // Ingress control block begins executing.
  ClassOfService_t         class_of_service; // 0
  bool                     clone;            // false
  CloneSessionId_t         clone_session_id; // initial value is undefined
  bool                     drop;             // true
  bool                     resubmit;         // false
  MulticastGroup_t         multicast_group;  // 0
  PortId_t                 egress_port;      // initial value is undefined
}
// end::Metadata_ingress_output[]
struct psa_egress_input_metadata_t {
  ClassOfService_t         class_of_service;
  PortId_t                 egress_port;
  PSA_PacketPath_t         packet_path;
  EgressInstance_t         instance;       /// instance comes from the PacketReplicationEngine
  Timestamp_t              egress_timestamp;
  ParserError_t            parser_error;
}

/// This struct is an 'in' parameter to the egress deparser.  It
/// includes enough data for the egress deparser to distinguish
/// whether the packet should be recirculated or not.
struct psa_egress_deparser_input_metadata_t {
  PortId_t                 egress_port;
}
// tag::Metadata_egress_output[]
struct psa_egress_output_metadata_t {
  // The comment after each field specifies its initial value when the
  // Egress control block begins executing.
  bool                     clone;         // false
  CloneSessionId_t         clone_session_id; // initial value is undefined
  bool                     drop;          // false
}
// end::Metadata_egress_output[]
// end::Metadata_types[]

/// During the IngressDeparser execution, psa_clone_i2e returns true
/// if and only if a clone of the ingress packet is being made to
/// egress for the packet being processed.  If there are any
/// assignments to the out parameter clone_i2e_meta in the
/// IngressDeparser, they must be inside an if statement that only
/// allows those assignments to execute if psa_clone_i2e(istd) returns
/// true.  psa_clone_i2e can be implemented by returning istd.clone

@pure
extern bool psa_clone_i2e(in psa_ingress_output_metadata_t istd);

/// During the IngressDeparser execution, psa_resubmit returns true if
/// and only if the packet is being resubmitted.  If there are any
/// assignments to the out parameter resubmit_meta in the
/// IngressDeparser, they must be inside an if statement that only
/// allows those assignments to execute if psa_resubmit(istd) returns
/// true.  psa_resubmit can be implemented by returning (!istd.drop &&
/// istd.resubmit)

@pure
extern bool psa_resubmit(in psa_ingress_output_metadata_t istd);

/// During the IngressDeparser execution, psa_normal returns true if
/// and only if the packet is being sent 'normally' as unicast or
/// multicast to egress.  If there are any assignments to the out
/// parameter normal_meta in the IngressDeparser, they must be inside
/// an if statement that only allows those assignments to execute if
/// psa_normal(istd) returns true.  psa_normal can be implemented by
/// returning (!istd.drop && !istd.resubmit)

@pure
extern bool psa_normal(in psa_ingress_output_metadata_t istd);

/// During the EgressDeparser execution, psa_clone_e2e returns true if
/// and only if a clone of the egress packet is being made to egress
/// for the packet being processed.  If there are any assignments to
/// the out parameter clone_e2e_meta in the EgressDeparser, they must
/// be inside an if statement that only allows those assignments to
/// execute if psa_clone_e2e(istd) returns true.  psa_clone_e2e can be
/// implemented by returning istd.clone

@pure
extern bool psa_clone_e2e(in psa_egress_output_metadata_t istd);

/// During the EgressDeparser execution, psa_recirculate returns true
/// if and only if the packet is being recirculated.  If there are any
/// assignments to recirculate_meta in the EgressDeparser, they must
/// be inside an if statement that only allows those assignments to
/// execute if psa_recirculate(istd) returns true.  psa_recirculate
/// can be implemented by returning (!istd.drop && (edstd.egress_port
/// == PSA_PORT_RECIRCULATE))

@pure
extern bool psa_recirculate(in psa_egress_output_metadata_t istd,
                            in psa_egress_deparser_input_metadata_t edstd);


/***
 * Calling assert when the argument is true has no effect, except any
 * effect that might occur due to evaluation of the argument (but see
 * below).  If the argument is false, the precise behavior is
 * target-specific, but the intent is to record or log which assert
 * statement failed, and optionally other information about the
 * failure.
 *
 * For example, on the simple_switch_psa target, executing an assert
 * statement with a false argument causes a log message with the file
 * name and line number of the assert statement to be printed, and
 * then the simple_switch_psa process exits.
 *
 * If you use a P4 compiler whose front end is based on the open
 * source p4c front end, then providing the --ndebug command line
 * option to p4c causes the compiled program to behave as if all
 * assert statements were not present in the source code.  Consult the
 * documentation of your device's P4 compiler for information on how
 * it handles assert statements, and if it supports a similar option.
 *
 * We strongly recommend that you avoid using expressions as an
 * argument to an assert call that can have side effects, e.g. an
 * extern method or function call that has side effects.  p4c will
 * allow you to do this with no warning given.  We recommend this
 * because, if you follow this advice, your program will behave the
 * same way when assert statements are removed.
 */
extern void assert(in bool check);

/***
 * For the purposes of compiling and executing P4 programs on a target
 * device, assert and assume are identical, including the use of the
 * --ndebug option to compilers based on the open source p4c front end
 * to elide them.  See documentation for assert.
 *
 * The reason that assume exists as a separate function from assert is
 * because they are expected to be used differently by formal
 * verification tools.  For some formal tools, the goal is to try to
 * find example packets and sets of installed table entries that cause
 * an assert statement condition to be false.
 *
 * Suppose you run such a tool on your program, and the example packet
 * given is an MPLS packet, i.e. hdr.ethernet.etherType == 0x8847.
 * You look at the example, and indeed it does cause an assert
 * condition to be false.  However, your plan is to deploy your P4
 * program in a network in places where no MPLS packets can occur.
 * You could add extra conditions to your P4 program to handle the
 * processing of such a packet cleanly, without assertions failing,
 * but you would prefer to tell the tool "such example packets are not
 * applicable in my scenario -- never show them to me".  By adding a
 * statement:
 *
 *     assume(hdr.ethernet.etherType != 0x8847);
 *
 * at an appropriate place in your program, the formal tool should
 * never show you such examples -- only ones that make all such assume
 * conditions true.
 *
 * The reason that assume statements behave the same as assert
 * statements when compiled to a target device is that if the
 * condition ever evaluates to false when operating in a network, it
 * is likely that your assumption was wrong, and should be reexamined.
 */
extern void assume(in bool check);

// tag::Match_kinds[]
match_kind {
    range,    /// Used to represent min..max intervals
    selector, /// Used for dynamic action selection via the ActionSelector extern
    optional  /// Either an exact match, or a wildcard matching any value for the entire field
}
// end::Match_kinds[]

// tag::Action_send_to_port[]
/// Modify ingress output metadata to cause one packet to be sent to
/// egress processing, and then to the output port egress_port.
/// (Egress processing may choose to drop the packet instead.)

/// This action does not change whether a clone or resubmit operation
/// will occur.

@noWarn("unused")
action send_to_port(inout psa_ingress_output_metadata_t meta,
                    in PortId_t egress_port)
{
    meta.drop = false;
    meta.multicast_group = (MulticastGroup_t) 0;
    meta.egress_port = egress_port;
}
// end::Action_send_to_port[]

// tag::Action_multicast[]
/// Modify ingress output metadata to cause 0 or more copies of the
/// packet to be sent to egress processing.

/// This action does not change whether a clone or resubmit operation
/// will occur.

@noWarn("unused")
action multicast(inout psa_ingress_output_metadata_t meta,
                 in MulticastGroup_t multicast_group)
{
    meta.drop = false;
    meta.multicast_group = multicast_group;
}
// end::Action_multicast[]

// tag::Action_ingress_drop[]
/// Modify ingress output metadata to cause no packet to be sent for
/// normal egress processing.

/// This action does not change whether a clone will occur.  It will
/// prevent a packet from being resubmitted.

@noWarn("unused")
action ingress_drop(inout psa_ingress_output_metadata_t meta)
{
    meta.drop = true;
}
// end::Action_ingress_drop[]

// tag::Action_egress_drop[]
/// Modify egress output metadata to cause no packet to be sent out of
/// the device.

/// This action does not change whether a clone will occur.

@noWarn("unused")
action egress_drop(inout psa_egress_output_metadata_t meta)
{
    meta.drop = true;
}
// end::Action_egress_drop[]

extern PacketReplicationEngine {
    PacketReplicationEngine();
    // There are no methods for this object callable from a P4
    // program.  This extern exists so it will have an instance with a
    // name that the control plane can use to make control plane API
    // calls on this object.
}

extern BufferingQueueingEngine {
    BufferingQueueingEngine();
    // There are no methods for this object callable from a P4
    // program.  See comments for PacketReplicationEngine.
}

// tag::Hash_algorithms[]
enum PSA_HashAlgorithm_t {
  IDENTITY,
  CRC32,
  CRC32_CUSTOM,
  CRC16,
  CRC16_CUSTOM,
  ONES_COMPLEMENT16,  /// One's complement 16-bit sum used for IPv4 headers,
                      /// TCP, and UDP.
  TARGET_DEFAULT      /// target implementation defined
}
// end::Hash_algorithms[]

// tag::Hash_extern[]
extern Hash<O> {
  /// Constructor
  Hash(PSA_HashAlgorithm_t algo);

  /// Compute the hash for data.
  /// @param data The data over which to calculate the hash.
  /// @return The hash value.
  @pure
  O get_hash<D>(in D data);

  /// Compute the hash for data, with modulo by max, then add base.
  /// @param base Minimum return value.
  /// @param data The data over which to calculate the hash.
  /// @param max The hash value is divided by max to get modulo.
  ///        An implementation may limit the largest value supported,
  ///        e.g. to a value like 32, or 256, and may also only
  ///        support powers of 2 for this value.  P4 developers should
  ///        limit their choice to such values if they wish to
  ///        maximize portability.
  /// @return (base + (h % max)) where h is the hash value.
  @pure
  O get_hash<T, D>(in T base, in D data, in T max);
}
// end::Hash_extern[]

// tag::Checksum_extern[]
extern Checksum<W> {
  /// Constructor
  Checksum(PSA_HashAlgorithm_t hash);

  /// Reset internal state and prepare unit for computation.
  /// Every instance of a Checksum object is automatically initialized as
  /// if clear() had been called on it. This initialization happens every
  /// time the object is instantiated, that is, whenever the parser or control
  /// containing the Checksum object are applied.
  /// All state maintained by the Checksum object is independent per packet.
  void clear();

  /// Add data to checksum
  void update<T>(in T data);

  /// Get checksum for data added (and not removed) since last clear
  @noSideEffects
  W    get();
}
// end::Checksum_extern[]

// tag::InternetChecksum_extern[]
// Checksum based on `ONES_COMPLEMENT16` algorithm used in IPv4, TCP, and UDP.
// Supports incremental updating via `subtract` method.
// See IETF RFC 1624.
extern InternetChecksum {
  /// Constructor
  InternetChecksum();

  /// Reset internal state and prepare unit for computation.  Every
  /// instance of an InternetChecksum object is automatically
  /// initialized as if clear() had been called on it, once for each
  /// time the parser or control it is instantiated within is
  /// executed.  All state maintained by it is independent per packet.
  void clear();

  /// Add data to checksum.  data must be a multiple of 16 bits long.
  void add<T>(in T data);

  /// Subtract data from existing checksum.  data must be a multiple of
  /// 16 bits long.
  void subtract<T>(in T data);

  /// Get checksum for data added (and not removed) since last clear
  @noSideEffects
  bit<16> get();

  /// Get current state of checksum computation.  The return value is
  /// only intended to be used for a future call to the set_state
  /// method.
  @noSideEffects
  bit<16> get_state();

  /// Restore the state of the InternetChecksum instance to one
  /// returned from an earlier call to the get_state method.  This
  /// state could have been returned from the same instance of the
  /// InternetChecksum extern, or a different one.
  void set_state(in bit<16> checksum_state);
}
// end::InternetChecksum_extern[]

// tag::CounterType_defn[]
enum PSA_CounterType_t {
    PACKETS,
    BYTES,
    PACKETS_AND_BYTES
}
// end::CounterType_defn[]

// tag::Counter_extern[]
/// Indirect counter with n_counters independent counter values, where
/// every counter value has a data plane size specified by type W.

@noWarn("unused")
extern Counter<W, S> {
  Counter(bit<32> n_counters, PSA_CounterType_t type);
  void count(in S index);
}
// end::Counter_extern[]

// tag::DirectCounter_extern[]
@noWarn("unused")
extern DirectCounter<W> {
  DirectCounter(PSA_CounterType_t type);
  void count();
}
// end::DirectCounter_extern[]

// tag::MeterType_defn[]
enum PSA_MeterType_t {
    PACKETS,
    BYTES
}
// end::MeterType_defn[]

// tag::MeterColor_defn[]
enum PSA_MeterColor_t { RED, GREEN, YELLOW }
// end::MeterColor_defn[]

// tag::Meter_extern[]
// Indexed meter with n_meters independent meter states.

extern Meter<S> {
  Meter(bit<32> n_meters, PSA_MeterType_t type);

  // Use this method call to perform a color aware meter update (see
  // RFC 2698). The color of the packet before the method call was
  // made is specified by the color parameter.
  PSA_MeterColor_t execute(in S index, in PSA_MeterColor_t color);

  // Use this method call to perform a color blind meter update (see
  // RFC 2698).  It may be implemented via a call to execute(index,
  // MeterColor_t.GREEN), which has the same behavior.
  PSA_MeterColor_t execute(in S index);
}
// end::Meter_extern[]

// tag::DirectMeter_extern[]
extern DirectMeter {
  DirectMeter(PSA_MeterType_t type);
  // See the corresponding methods for extern Meter.
  PSA_MeterColor_t execute(in PSA_MeterColor_t color);
  PSA_MeterColor_t execute();
}
// end::DirectMeter_extern[]

// tag::Register_extern[]
extern Register<T, S> {
  /// Instantiate an array of <size> registers. The initial value is
  /// undefined.
  Register(bit<32> size);
  /// Initialize an array of <size> registers and set their value to
  /// initial_value.
  Register(bit<32> size, T initial_value);

  @noSideEffects
  T    read  (in S index);
  void write (in S index, in T value);
}
// end::Register_extern[]

// tag::Random_extern[]
extern Random<T> {

  /// Return a random value in the range [min, max], inclusive.
  /// Implementations are allowed to support only ranges where (max -
  /// min + 1) is a power of 2.  P4 developers should limit their
  /// arguments to such values if they wish to maximize portability.

  Random(T min, T max);
  T read();
}
// end::Random_extern[]

// tag::ActionProfile_extern[]
extern ActionProfile {
  /// Construct an action profile of 'size' entries
  ActionProfile(bit<32> size);
}
// end::ActionProfile_extern[]

// tag::ActionSelector_extern[]
extern ActionSelector {
  /// Construct an action selector of 'size' entries
  /// @param algo hash algorithm to select a member in a group
  /// @param size number of entries in the action selector
  /// @param outputWidth size of the key
  ActionSelector(PSA_HashAlgorithm_t algo, bit<32> size, bit<32> outputWidth);
}
// end::ActionSelector_extern[]

// tag::Digest_extern[]
extern Digest<T> {
  Digest();                       /// define a digest stream to the control plane
  void pack(in T data);           /// emit data into the stream
}
// end::Digest_extern[]

// tag::Programmable_blocks[]
parser IngressParser<H, M, RESUBM, RECIRCM>(
    packet_in buffer,
    out H parsed_hdr,
    inout M user_meta,
    in psa_ingress_parser_input_metadata_t istd,
    in RESUBM resubmit_meta,
    in RECIRCM recirculate_meta);

control Ingress<H, M>(
    inout H hdr, inout M user_meta,
    in    psa_ingress_input_metadata_t  istd,
    inout psa_ingress_output_metadata_t ostd);

control IngressDeparser<H, M, CI2EM, RESUBM, NM>(
    packet_out buffer,
    out CI2EM clone_i2e_meta,
    out RESUBM resubmit_meta,
    out NM normal_meta,
    inout H hdr,
    in M meta,
    in psa_ingress_output_metadata_t istd);

parser EgressParser<H, M, NM, CI2EM, CE2EM>(
    packet_in buffer,
    out H parsed_hdr,
    inout M user_meta,
    in psa_egress_parser_input_metadata_t istd,
    in NM normal_meta,
    in CI2EM clone_i2e_meta,
    in CE2EM clone_e2e_meta);

control Egress<H, M>(
    inout H hdr, inout M user_meta,
    in    psa_egress_input_metadata_t  istd,
    inout psa_egress_output_metadata_t ostd);

control EgressDeparser<H, M, CE2EM, RECIRCM>(
    packet_out buffer,
    out CE2EM clone_e2e_meta,
    out RECIRCM recirculate_meta,
    inout H hdr,
    in M meta,
    in psa_egress_output_metadata_t istd,
    in psa_egress_deparser_input_metadata_t edstd);

package IngressPipeline<IH, IM, NM, CI2EM, RESUBM, RECIRCM>(
    IngressParser<IH, IM, RESUBM, RECIRCM> ip,
    Ingress<IH, IM> ig,
    IngressDeparser<IH, IM, CI2EM, RESUBM, NM> id);

package EgressPipeline<EH, EM, NM, CI2EM, CE2EM, RECIRCM>(
    EgressParser<EH, EM, NM, CI2EM, CE2EM> ep,
    Egress<EH, EM> eg,
    EgressDeparser<EH, EM, CE2EM, RECIRCM> ed);

package PSA_Switch<IH, IM, EH, EM, NM, CI2EM, CE2EM, RESUBM, RECIRCM> (
    IngressPipeline<IH, IM, NM, CI2EM, RESUBM, RECIRCM> ingress,
    PacketReplicationEngine pre,
    EgressPipeline<EH, EM, NM, CI2EM, CE2EM, RECIRCM> egress,
    BufferingQueueingEngine bqe);

// end::Programmable_blocks[]

#endif   // __PSA_P4__
