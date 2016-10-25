
SPEC=P4-16-draft-spec

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --odir=build $<

build/${SPEC}.pdf: grammar.mdk p4.json

clean:
	${RM} -rf build
