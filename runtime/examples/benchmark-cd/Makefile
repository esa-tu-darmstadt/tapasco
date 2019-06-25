include ../Makefile.common
LDFLAGS += -pthread

BINDIR = bin/$(ARCH)

.PHONY:	all clean dist-clean

all:	libs $(BINDIR) $(BINDIR)/benchmark-cd

$(BINDIR):
	@mkdir -p $@

$(BINDIR)/benchmark-cd:	benchmark-cd.c
	$(CC) $(CFLAGS) -o $@ $(LDFLAGS) benchmark-cd.c

clean:
	@rm -rf $(BINDIR)

dist-clean:	dist-clean-libs
	@rm -rf `dirname $(BINDIR)`

include ../Makefile.libs
