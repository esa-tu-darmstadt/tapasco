PDFLATEX ?= pdflatex
.PHONY: all clean clean-pdf

TEXSRC=$(wildcard *.tex)
TEXPDF=$(patsubst %.tex,%.pdf,$(TEXSRC))

%.pdf: %.tex
	$(PDFLATEX) $<

all: $(TEXPDF)

clean-pdf: 
	rm -f *.pdf *.log *.aux *.fdb_latexmk *.fls

clean: clean-pdf

