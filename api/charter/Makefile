
SPEC=P4_API_WG_charter

build/${SPEC}.pdf: ${SPEC}.mdk
	madoko -vv --png --odir=build $<

clean:
	${RM} -rf build
