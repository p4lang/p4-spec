
SPEC=PSA
CHARTER=P4_Arch_Charter

all: build/${SPEC}.pdf build/${CHARTER}.pdf

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --odir=build $<

build/${CHARTER}.pdf: charter/${CHARTER}.mdk
	madoko -vv --odir=build $<

build/${SPEC}.pdf: p4.json
build/${SPEC}.pdf: psa.p4

clean:
	${RM} -rf build

# Disabling warnings about uninitialized_out_param, because those
# regularly occur with these example programs for the 'out
# psa_parser_output_metadata_t ostd' parameter of the parsers.

P4C=p4test --Wdisable=uninitialized_out_param

check:
	${P4C} examples/psa-example-bridged-metadata.p4
	${P4C} examples/psa-example-clone-to-port.p4
	${P4C} examples/psa-example-counters.p4
	${P4C} examples/psa-example-incremental-checksum.p4
	${P4C} examples/psa-example-parser-checksum.p4
	${P4C} examples/psa-example-recirculate.p4
	${P4C} examples/psa-example-register2.p4
	${P4C} examples/psa-example-resubmit.p4
	${P4C} examples/psa-example-value-sets.p4
	${P4C} examples/psa-example-value-sets2.p4
	${P4C} examples/psa-example-value-sets3.p4

check-others:

# psa-example-digest.p4 needs updates for latest psa.p4
#	${P4C} examples/psa-example-digest.p4

# psa-example-mirror-on-drop.p4 needs updates for latest psa.p4
#	${P4C} examples/psa-example-mirror-on-drop.p4

# psa-example-incremental-checksum2.p4 fails with latest p4test as of
# 2017-Dec-04 because of call to InternetChecksum method set_state(),
# because its argument is not a compile-time constant.  I am not sure
# why that should be a problem.
#	${P4C} examples/psa-example-incremental-checksum2.p4

# psa-example-register1.p4 is almost identical to
# psa-example-register2.p4, except that it attempts to return a struct
# from a register read, and write a struct back to the register.  As
# of 2017-Dec-04, the latest version of p4test gives an error if you
# attempt this.
#	${P4C} examples/psa-example-register1.p4
