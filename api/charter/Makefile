SPEC=P4_API_WG_charter
ROUGE_STYLE=molokai
ROUGE_CSS=style

${SPEC}.pdf: ${SPEC}.adoc
	asciidoctor-pdf -v \
		--failure-level ERROR \
		-a pdf-fontsdir=resources/fonts \
		-a rouge-style=$(ROUGE_STYLE) $<

clean:
	${RM} -rf build
