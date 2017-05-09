MK ?= latexmk
MKFLAGS += -pdf

PDF = "ThreadpoolComposer.pdf"
MAINTEX = ThreadpoolComposer.tex

.PHONY: $(PDF) clean tikz tikz-clean

$(PDF): tikz
	$(MK) $(MKFLAGS) $(MAINTEX)

clean: tikz-clean
	$(MK) -C $(MAINTEX)

tikz:
	$(MAKE) -C tikz

tikz-clean:
	$(MAKE) -C tikz clean

