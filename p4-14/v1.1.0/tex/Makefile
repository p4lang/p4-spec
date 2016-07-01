#
# Makefile for p4.tex. 

p4.pdf: p4.tex p4doc.sty
	texi2pdf -b p4.tex

p4.tex: addendum.tex p4.pt pretext.py
	./pretext.py p4.pt --output=$@

addendum.tex: addendum.pt pretext.py
	./pretext.py addendum.pt --output=$@

clean:
	rm -f *.tex *.aux *.log *.out *.bbl *.blg *~ *.bak *.ps *.pdf *.tpt
