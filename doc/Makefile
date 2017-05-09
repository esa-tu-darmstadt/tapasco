MK ?= latexmk
MKFLAGS += -pdf

PDF = "Tapasco.pdf"
MAINTEX = Tapasco.tex

.PHONY: $(PDF) clean tikz tikz-clean

$(PDF): tikz
	$(MK) $(MKFLAGS) $(MAINTEX)

clean: tikz-clean
	$(MK) -C $(MAINTEX)

tikz:
	$(MAKE) -C tikz

tikz-clean:
	$(MAKE) -C tikz clean

