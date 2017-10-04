/*
Copyright 2013-present Barefoot Networks, Inc.

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

#ifndef _PORTABLE_SWITCH_ARCHITECTURE_P4_
#define _PORTABLE_SWITCH_ARCHITECTURE_P4_

/**
 *   P4-16 declaration of the Portable Switch Architecture
 */

/**
 * These types need to be defined before including the architecture file
 * and the macro protecting them should be defined.
 */
#define PSA_CORE_TYPES
#ifdef PSA_CORE_TYPES
/* The bit widths shown below are only examples.  Each PSA
 * implementation is free to use its own custom width in bits for
 * those types that are bit<W> for some W.  The only reason that there
 * are example numerical widths in this file is so that we can easily
 * compile this file, and example PSA P4 programs that include it. */

typedef bit<10> PortId_t;
typedef bit<10> MulticastGroup_t;
typedef bit<3>  ClassOfService_t;
typedef bit<14> PacketLength_t;
typedef bit<16> EgressInstance_t;
typedef bit<48> Timestamp_t;
typedef error   ParserError_t;

const   PortId_t         PORT_CPU = 255;

// typedef bit<unspecified> InstanceType_t;
// const   InstanceType_t   INSTANCE_NORMAL = unspecified;
#endif  // PSA_CORE_TYPES
#ifndef PSA_CORE_TYPES
#error "Please define the following types for PSA and the PSA_CORE_TYPES macro"
// BEGIN:Type_defns
typedef bit<unspecified> PortId_t;
typedef bit<unspecified> MulticastGroup_t;
typedef bit<unspecified> ClassOfService_t;
typedef bit<unspecified> PacketLength_t;
typedef bit<unspecified> EgressInstance_t;
typedef bit<unspecified> Timestamp_t;

const   PortId_t         PORT_CPU = unspecified;
// END:Type_defns

// typedef bit<unspecified> InstanceType_t;
// const   InstanceType_t   INSTANCE_NORMAL = unspecified;
#endif

// BEGIN:Metadata_types
enum InstanceType_t {
    NORMAL,     /// Packet is "normal", i.e. none of the other cases below
    CLONE,      /// Packet was created via a clone operation
    RESUBMIT,   /// Packet arrival is the result of a resubmit operation
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

struct psa_ingress_parser_input_metadata_t {
  PortId_t                 ingress_port;
  InstanceType_t           instance_type;
}

struct psa_egress_parser_input_metadata_t {
  PortId_t                 egress_port;
  InstanceType_t           instance_type;
}

struct psa_parser_output_metadata_t {
  ParserError_t            parser_error;
}

struct psa_ingress_input_metadata_t {
  // All of these values are initialized by the architecture before
  // the Ingress control block begins executing.
  PortId_t                 ingress_port;
  InstanceType_t           instance_type;
  Timestamp_t              ingress_timestamp;
  ParserError_t            parser_error;
}
// BEGIN:Metadata_ingress_output
struct psa_ingress_output_metadata_t {
  // The comment after each field specifies its initial value when the
  // Ingress control block begins executing.
  ClassOfService_t         class_of_service; // 0
  bool                     clone;            // false
  PortId_t                 clone_port;       // undefined
  ClassOfService_t         clone_class_of_service; // 0
  bool                     drop;             // true
  bool                     resubmit;         // false
  MulticastGroup_t         multicast_group;  // 0
  PortId_t                 egress_port;      // undefined
  bool                     truncate;         // false
  PacketLength_t           truncate_payload_bytes;  // undefined
}
// END:Metadata_ingress_output
struct psa_egress_input_metadata_t {
  ClassOfService_t         class_of_service;
  PortId_t                 egress_port;
  InstanceType_t           instance_type;
  EgressInstance_t         instance;       /// instance coming from PRE
  Timestamp_t              egress_timestamp;
  ParserError_t            parser_error;
}
// BEGIN:Metadata_egress_output
struct psa_egress_output_metadata_t {
  // The comment after each field specifies its initial value when the
  // Egress control block begins executing.
  bool                     clone;         // false
  ClassOfService_t         clone_class_of_service; // 0
  bool                     drop;          // false
  bool                     recirculate;   // false
  bool                     truncate;      // false
  PacketLength_t           truncate_payload_bytes;  // undefined
}
// END:Metadata_egress_output
// END:Metadata_types

// BEGIN:Match_kinds
match_kind {
    range,   /// Used to represent min..max intervals
    selector /// Used for implementing dynamic_action_selection
}
// END:Match_kinds

// BEGIN:Action_send_to_port
/// Modify ingress output metadata to cause one packet to be sent to
/// egress processing, and then to the output port egress_port, unless
/// it is dropped during egress processing.

/// This action does not change whether a clone or resubmit operation
/// will occur.

/// The one copy it causes to be sent to egress processing will have
/// its struct of type psa_egress_input_metadata_t filled in as
/// follows:

/// egress_port - equal to the egress_port parameter of this action
/// instance_type - InstanceType_t.NORMAL
/// instance - undefined
/// egress_timestamp - the time the packet begins egress processing

action send_to_port(inout psa_ingress_output_metadata_t meta,
                    in PortId_t egress_port)
{
    meta.drop = false;
    meta.multicast_group = 0;
    meta.egress_port = egress_port;
}
// END:Action_send_to_port

// BEGIN:Action_multicast
/// Modify ingress output metadata to cause 0 or more copies of the
/// packet to be sent to egress processing.

/// This action does not change whether a clone or resubmit operation
/// will occur.

/// The control plane must program each multicast_group to create the
/// desired copies of the packet.  For a particular multicast group,
/// the control plane specifies a list of 0 or more copy
/// specifications:

/// (egress_port[0], instance[0]),
/// (egress_port[1], instance[1]),
/// ...,
/// (egress_port[N-1], instance[N-1])

/// Copy number i sent to egress processing will have its struct of
/// type psa_egress_input_metadata_t filled in as follows:

/// egress_port - equal to the egress_port[i]
/// instance_type - InstanceType_t.NORMAL
/// instance - instance[i]
/// egress_timestamp - the time the packet begins egress processing

action multicast(inout psa_ingress_output_metadata_t meta,
                 in MulticastGroup_t multicast_group)
{
    meta.drop = false;
    meta.multicast_group = multicast_group;
}
// END:Action_multicast

// BEGIN:Action_ingress_drop
/// Modify ingress output metadata to cause no packet to be sent for
/// normal egress processing.

/// This action does not change whether a clone will occur.  It will
/// prevent a packet from being resubmitted.

action ingress_drop(inout psa_ingress_output_metadata_t meta)
{
    meta.drop = true;
}
// END:Action_ingress_drop

// BEGIN:Action_ingress_truncate
/// For any copies made of this packet at the end of Ingress
/// processing, truncate the payload to at most payload_bytes bytes in
/// length.

action ingress_truncate(inout psa_ingress_output_metadata_t meta,
                        in PacketLength_t payload_bytes)
{
    meta.truncate = true;
    meta.truncate_payload_bytes = payload_bytes;
}
// END:Action_ingress_truncate

// BEGIN:Action_egress_drop
/// Modify egress output metadata to cause no packet to be sent out of
/// the device.

/// This action does not change whether a clone will occur.  It will
/// prevent a packet from being recirculated.

action egress_drop(inout psa_egress_output_metadata_t meta)
{
    meta.drop = true;
}
// END:Action_egress_drop

// BEGIN:Action_egress_truncate
/// For any copies made of this packet at the end of Egress
/// processing, truncate the payload to at most payload_bytes bytes in
/// length.

action egress_truncate(inout psa_ingress_output_metadata_t meta,
                       in PacketLength_t payload_bytes)
{
    meta.truncate = true;
    meta.truncate_payload_bytes = payload_bytes;
}
// END:Action_egress_truncate

extern PacketReplicationEngine {

  // PacketReplicationEngine(); /// No constructor. PRE is instantiated
                                /// by the architecture.
}

extern BufferingQueueingEngine {

  // BufferingQueueingEngine(); /// No constructor. BQE is instantiated
                                /// by the architecture.

}

// BEGIN:Clone_extern
extern clone {
  /// Write @hdr into the ingress/egress clone engine.
  /// @T can be a header type, a header stack, a header union, or a struct
  /// containing fields with such types.
  void emit<T>(in T hdr);
}
// END:Clone_extern


// BEGIN:Resubmit_extern
extern resubmit {
  /// Write @hdr into the ingress packet buffer.
  /// @T can be a header type, a header stack, a header union or a struct
  /// containing fields with such types.
  void emit<T>(in T hdr);
}
// END:Resubmit_extern

// BEGIN:Recirculate_extern
extern recirculate {
  /// Write @hdr into the egress packet.
  /// @T can be a header type, a header stack, a header union or a struct
  /// containing fields with such types.
  void emit(in T hdr);
}
// END:Recirculate_extern

// BEGIN:Hash_algorithms
enum HashAlgorithm_t {
  IDENTITY,
  CRC32,
  CRC32_CUSTOM,
  CRC16,
  CRC16_CUSTOM,
  ONES_COMPLEMENT16,  /// One's complement 16-bit sum used for IPv4 headers,
                      /// TCP, and UDP.
  TARGET_DEFAULT      /// target implementation defined
}
// END:Hash_algorithms

// BEGIN:Hash_extern
extern Hash<O> {
  /// Constructor
  Hash(HashAlgorithm_t algo);

  /// Compute the hash for data.
  /// @param data The data over which to calculate the hash.
  /// @return The hash value.
  O get_hash<D>(in D data);

  /// Compute the hash for data, with modulo by max, then add base.
  /// @param base Minimum return value.
  /// @param data The data over which to calculate the hash.
  /// @param max The hash value is divided by max to get modulo.
  ///        An implementation may limit the largest value supported,
  ///        e.g. to a value like 32, or 256.
  /// @return (base + (h % max)) where h is the hash value.
  O get_hash<T, D>(in T base, in D data, in T max);
}
// END:Hash_extern

// BEGIN:Checksum_extern
extern Checksum<W> {
  Checksum(HashAlgorithm_t hash);          /// constructor
  void clear();              /// prepare unit for computation
  void update<T>(in T data); /// add data to checksum
  void remove<T>(in T data); /// remove data from existing checksum
  W    get();      	     /// get the checksum for data added since last clear
}
// END:Checksum_extern

// BEGIN:CounterType_defn
enum CounterType_t {
    PACKETS,
    BYTES,
    PACKETS_AND_BYTES
}
// END:CounterType_defn

// BEGIN:Counter_extern
/// Indirect counter with n_counters independent counter values, where
/// every counter value has a data plane size specified by type W.

extern Counter<W, S> {
  Counter(bit<32> n_counters, CounterType_t type);
  void count(in S index);

  /*
  /// The control plane API uses 64-bit wide counter values.  It is
  /// not intended to represent the size of counters as they are
  /// stored in the data plane.  It is expected that control plane
  /// software will periodically read the data plane counter values,
  /// and accumulate them into larger counters that are large enough
  /// to avoid reaching their maximum values for a suitably long
  /// operational time.  A 64-bit byte counter increased at maximum
  /// line rate for a 100 gigabit port would take over 46 years to
  /// wrap.

  @ControlPlaneAPI
  {
    bit<64> read      (in S index);
    bit<64> sync_read (in S index);
    void set          (in S index, in bit<64> seed);
    void reset        (in S index);
    void start        (in S index);
    void stop         (in S index);
  }
  */
}
// END:Counter_extern

// BEGIN:DirectCounter_extern
extern DirectCounter<W> {
  DirectCounter(CounterType_t type);
  void count();

  /*
  @ControlPlaneAPI
  {
    W    read<W>      (in TableEntry key);
    W    sync_read<W> (in TableEntry key);
    void set          (in W seed);
    void reset        (in TableEntry key);
    void start        (in TableEntry key);
    void stop         (in TableEntry key);
  }
  */
}
// END:DirectCounter_extern

// BEGIN:MeterType_defn
enum MeterType_t {
    PACKETS,
    BYTES
}
// END:MeterType_defn

// BEGIN:MeterColor_defn
enum MeterColor_t { RED, GREEN, YELLOW };
// END:MeterColor_defn

// BEGIN:Meter_extern
// Indexed meter with n_meters independent meter states.

extern Meter<S> {
  Meter(bit<32> n_meters, MeterType_t type);

  // Use this method call to perform a color aware meter update (see
  // RFC 2698). The color of the packet before the method call was
  // made is specified by the color parameter.
  MeterColor_t execute(in S index, in MeterColor_t color);

  // Use this method call to perform a color blind meter update (see
  // RFC 2698).  It may be implemented via a call to execute(index,
  // MeterColor_t.GREEN), which has the same behavior.
  MeterColor_t execute(in S index);

  /*
  @ControlPlaneAPI
  {
    reset(in MeterColor_t color);
    setParams(in S index, in MeterConfig config);
    getParams(in S index, out MeterConfig config);
  }
  */
}
// END:Meter_extern

// BEGIN:DirectMeter_extern
extern DirectMeter {
  DirectMeter(MeterType_t type);
  // See the corresponding methods for extern Meter.
  MeterColor_t execute(in MeterColor_t color);
  MeterColor_t execute();

  /*
  @ControlPlaneAPI
  {
    reset(in TableEntry entry, in MeterColor_t color);
    void setConfig(in TableEntry entry, in MeterConfig config);
    void getConfig(in TableEntry entry, out MeterConfig config);
  }
  */
}
// END:DirectMeter_extern

// BEGIN:Register_extern
extern Register<T, S> {
  Register(bit<32> size);
  T    read  (in S index);
  void write (in S index, in T value);

  /*
  @ControlPlaneAPI
  {
    T    read<T>      (in S index);
    void set          (in S index, in T seed);
    void reset        (in S index);
  }
  */
}
// END:Register_extern

// BEGIN:RandomDistribution_defn
enum RandomDistribution {
  PRNG,
  Binomial,
  Poisson
}
// END:RandomDistribution_defn

// BEGIN:Random_extern
extern Random<T> {
  Random(RandomDistribution dist, T min, T max);
  T read();

  /*
  @ControlPlaneAPI
  {
    void reset();
    void setSeed(in T seed);
  }
  */
}
// END:Random_extern

// BEGIN:ActionProfile_extern
extern ActionProfile {
  /// Construct an action profile of 'size' entries
  ActionProfile(bit<32> size);

  /*
  @ControlPlaneAPI
  {
     entry_handle add_member    (action_ref, action_data);
     void         delete_member (entry_handle);
     entry_handle modify_member (entry_handle, action_ref, action_data);
  }
  */
}
// END:ActionProfile_extern

// BEGIN:ActionSelector_extern
extern ActionSelector {
  /// Construct an action selector of 'size' entries
  /// @param algo hash algorithm to select a member in a group
  /// @param size number of entries in the action selector
  /// @param outputWidth size of the key
  ActionSelector(HashAlgorithm_t algo, bit<32> size, bit<32> outputWidth);

  /*
  @ControlPlaneAPI
  {
     entry_handle add_member        (action_ref, action_data);
     void         delete_member     (entry_handle);
     entry_handle modify_member     (entry_handle, action_ref, action_data);
     group_handle create_group      ();
     void         delete_group      (group_handle);
     void         add_to_group      (group_handle, entry_handle);
     void         delete_from_group (group_handle, entry_handle);
  }
  */
}
// END:ActionSelector_extern

// BEGIN:Digest_extern
extern Digest<T> {
  Digest(PortId_t receiver); /// define a digest stream to receiver
  void emit(in T data);      /// emit data into the stream

  /*
  @ControlPlaneAPI
  {
  // TBD
  // If the type T is a named struct, the name should be used
  // to generate the control-plane API.
  }
  */
}
// END:Digest_extern

// BEGIN:ValueSet_extern
extern ValueSet<D> {
    ValueSet(int<32> size);
    bool is_member(in D data);

    /*
    @ControlPlaneAPI
    message ValueSetEntry {
        uint32 value_set_id = 1;
        // FieldMatch allows specification of exact, lpm, ternary, and
        // range matching on fields for tables, and these options are
        // permitted for the ValueSet extern as well.
        repeated FieldMatch match = 2;
    }

    // ValueSetEntry should be added to the 'message Entity'
    // definition, inside its 'oneof Entity' list of possibilities.
    */
}
// END:ValueSet_extern

// BEGIN:Programmable_blocks
parser IngressParser<H, M>(packet_in buffer,
                           out H parsed_hdr,
                           inout M user_meta,
                           in psa_ingress_parser_input_metadata_t istd,
                           out psa_parser_output_metadata_t ostd);

control Ingress<H, M>(inout H hdr, inout M user_meta,
                      PacketReplicationEngine pre,
                      in  psa_ingress_input_metadata_t  istd,
                      out psa_ingress_output_metadata_t ostd);

parser EgressParser<H, M>(packet_in buffer,
                          out H parsed_hdr,
                          inout M user_meta,
                          in psa_egress_parser_input_metadata_t istd,
                          out psa_parser_output_metadata_t ostd);

control Egress<H, M>(inout H hdr, inout M user_meta,
                     BufferingQueueingEngine bqe,
                     in  psa_egress_input_metadata_t  istd,
                     out psa_egress_output_metadata_t ostd);

control ComputeChecksum<H, M>(inout H hdr, inout M user_meta);

control Deparser<H>(packet_out buffer, in H hdr);

package PSA_Switch<IH, IM, EH, EM>(IngressParser<IH, IM> ip,
                                   Ingress<IH, IM> ig,
                                   ComputeChecksum<IH, IM> ic,
                                   Deparser<IH> id,
                                   EgressParser<EH, EM> ep,
                                   Egress<EH, EM> eg,
                                   ComputeChecksum<EH, EM> ec,
                                   Deparser<EH> ed);
// END:Programmable_blocks

#endif  /* _PORTABLE_SWITCH_ARCHITECTURE_P4_ */
