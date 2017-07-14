DOXYGEN ?= doxygen

.PHONY: doc-all doc-full doc-header doc-clean clean

doc-all: doc-full doc-header

doc-full:
	cd doc; $(DOXYGEN) doxygen-full.conf

doc-header:
	cd doc; $(DOXYGEN) doxygen-header.conf

doc-clean:
	rm -rf doc/full doc/header

clean:	doc-clean
