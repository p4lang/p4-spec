
SPEC=P4-16-spec

all: build/${SPEC}.pdf

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --png --odir=build $<

build/${SPEC}.pdf: grammar.mdk p4.json

html: ${SPEC}.mdk grammar.mdk p4.json
	madoko -vv --png --odir=build $<
	
clean:
	${RM} -rf build
