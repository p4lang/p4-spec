Files with 'value-sets' in their name:

Parser value sets were originally considered to be defined as an
extern object in PSA, but all of the ways discussed were felt to be
too unwieldy, either for the P4 developer, the P4 compiler developers,
or both, vs. making parser value sets a new P4_16 language construct
defined in the language specification, similar to (but simpler than)
tables.  That happened in early 2018.  All files with 'value-sets' as
part of their name represent approaches considered for making them an
extern in PSA.
