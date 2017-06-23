
SPEC=P4-16-spec

all: build/${SPEC}.pdf

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --png --odir=build $<

build/${SPEC}.pdf: grammar.mdk p4.json

clean:
	${RM} -rf build
