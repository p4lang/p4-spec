.PHONY: charter

SPEC=PSA

all: build/${SPEC}.pdf charter

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --png --odir=build $<

build/${SPEC}.pdf: p4.json
build/${SPEC}.pdf: psa.p4

charter:
	$(MAKE) -C charter

clean:
	${RM} -rf build

# Disabling warnings about uninitialized_out_param, because those
# regularly occur with these example programs for the 'out
# psa_parser_output_metadata_t ostd' parameter of the parsers.

P4C=p4test
#P4C=p4test --Wdisable=uninitialized_out_param

# TBD: The lines commented out below are PSA example programs that
# have not yet been updated for the proposed new way of handling
# recirculate, resubmit, clone, and normal (aka bridged metadata)
# preserved metadata.

# Most of those commented out programs would look much like
# psa-example-drop-all.p4 in the changes required, since they do not
# preserve any metadata for those cases.

# psa-example-parser-error-handling.p4 does need some updates, most
# likely ones that look nearly identical to
# psa-example-parser-error-handling.p4

check:
	${P4C} examples/psa-example-drop-all.p4
	${P4C} examples/psa-example-hello-world.p4
	${P4C} examples/psa-example-bridged-metadata.p4
	${P4C} examples/psa-example-clone-to-port.p4
	#${P4C} examples/psa-example-counters.p4
	#${P4C} examples/psa-example-digest.p4
	#${P4C} examples/psa-example-incremental-checksum.p4
	#${P4C} examples/psa-example-incremental-checksum2.p4
	#${P4C} examples/psa-example-parser-checksum.p4
	#${P4C} examples/psa-example-parser-error-handling.p4
	${P4C} examples/psa-example-parser-error-handling2.p4
	${P4C} examples/psa-example-recirculate.p4
	#${P4C} examples/psa-example-register2.p4
	${P4C} examples/psa-example-resubmit.p4

# check-others:

# psa-example-mirror-on-drop.p4 needs updates for latest psa.p4
#	${P4C} examples/psa-example-mirror-on-drop.p4

# psa-example-register1.p4 is almost identical to
# psa-example-register2.p4, except that it attempts to return a struct
# from a register read, and write a struct back to the register.  As
# of 2018-Oct-19, the latest version of p4test gives an error if you
# attempt this, I believe somewhere in one of the mid end passes.  It
# is definitely not in the bmv2 back end code.
#	${P4C} examples/psa-example-register1.p4
