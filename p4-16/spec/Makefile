
SPEC=P4-16-draft-spec

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko --pdf -vv --png --odir=build $<

build/${SPEC}.pdf: grammar.mdk p4.json

clean:
	${RM} -rf build

P4SPEC_WIKI=p4-spec.wiki
NOW=$(shell date +"%Y-%m-%d %H:%M:%S")
install: build/${SPEC}.pdf
	git clone git@github.com:p4lang/${P4SPEC_WIKI}.git
	cp build/${SPEC}.pdf ${P4SPEC_WIKI}/
	cp build/${SPEC}.html ${P4SPEC_WIKI}/
	(cd ${P4SPEC_WIKI} && \
	 git commit -m "update spec as of ${NOW}" ${SPEC}.pdf ${SPEC}.html && \
	 git push origin master)
	${RM} -rf ${P4SPEC_WIKI}
