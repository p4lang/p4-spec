CHARTER=P4_Arch_Charter
ROUGE_STYLE=molokai
ROUGE_CSS=style

../build/${CHARTER}.html: ${CHARTER}.adoc
	asciidoctor -v -a rouge-css=$(ROUGE_CSS) $<
