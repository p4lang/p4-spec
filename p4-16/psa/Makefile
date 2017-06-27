
SPEC=PSA

all: build/${SPEC}.pdf

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --odir=build $<

build/${SPEC}.pdf: p4.json

clean:
	${RM} -rf build
