PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
MANDIR = $(PREFIX)/share/man
MAN1 = $(MANDIR)/man1
MAN5 = $(MANDIR)/man5

all:
	@echo Nothing to be done for $@

eol =
FILES = \
	$(BINDIR)/dirq \
	$(BINDIR)/dirqst \
	$(LIBDIR)/dirq.dat \
	$(MAN1)/dirq.1 \
	$(MAN1)/dirqst.1 \
	$(MAN5)/dirq.dat.5 \
	$(eol)

$(BINDIR)/%: %
	mkdir -p $(@D)
	cp $< $@
	chmod 755 $@

$(LIBDIR)/%: %
	mkdir -p $(@D)
	cp $< $@
	chmod 644 $@

$(MAN1)/%: %
	mkdir -p $(@D)
	cp $< $@
	chmod 644 $@

$(MAN5)/%: %
	mkdir -p $(@D)
	cp $< $@
	chmod 644 $@

install: $(FILES)
	@echo Installation complete.

