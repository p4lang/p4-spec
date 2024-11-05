
SPEC=P4-16-spec

ROUGE_STYLE=molokai
ROUGE_CSS=style

all: ${SPEC}.pdf ${SPEC}.html

grammar.trimmed.adoc: grammar.adoc trim-asciidoc-tag-comments.py
	./trim-asciidoc-tag-comments.py $< > $@

${SPEC}.pdf: ${SPEC}.adoc grammar.adoc grammar.trimmed.adoc
	time asciidoctor-pdf -v \
		-r asciidoctor-mathematical \
		-a pdf-fontsdir=resources/fonts \
		-a rouge-style=$(ROUGE_STYLE) $<

${SPEC}.html: ${SPEC}.adoc grammar.adoc grammar.trimmed.adoc
	time asciidoctor -v \
		-r asciidoctor-mathematical \
		-a rouge-css=$(ROUGE_CSS) $<

clean:
	/bin/rm -f ${SPEC}.pdf ${SPEC}.html grammar.trimmed.adoc resources/figs/stem-*.png
