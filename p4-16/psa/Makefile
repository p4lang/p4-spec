
SPEC=PSA

all: build/${SPEC}.pdf

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --odir=build $<

build/${SPEC}.pdf: p4.json
build/${SPEC}.pdf: psa.p4

clean:
	${RM} -rf build

P4C=p4test

check:
	${P4C} examples/psa-example-counters.p4
	${P4C} examples/psa-example-value-sets.p4
	${P4C} examples/psa-example-value-sets2.p4
	${P4C} examples/psa-example-value-sets3.p4
	${P4C} examples/psa-example-register2.p4
