
SPEC=P4-16-spec

all: build/${SPEC}.pdf

grammar.trimmed.mdk: grammar.mdk trim-madoko-comments.py
	./trim-madoko-comments.py $< > $@

build/${SPEC}.pdf: ${SPEC}.mdk grammar.mdk grammar.trimmed.mdk
	madoko --pdf -vv --png --odir=build $<

build/${SPEC}.pdf: grammar.mdk p4.json

html: ${SPEC}.mdk grammar.mdk grammar.trimmed.mdk p4.json
	madoko -vv --png --odir=build $<

clean:
	${RM} -rf build
