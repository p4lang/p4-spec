
SPEC=P4_Apps_WG_charter

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko -vv --png --odir=build $<

clean:
	${RM} -rf build
