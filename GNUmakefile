.PHONY: all clean test lint docs deps install
.DEFAULT_GOAL := all

CRYSTAL ?= crystal

all: lint test

deps:
	shards install

test: deps
	$(CRYSTAL) spec

lint: deps
	bin/ameba
	[ -f bin/flaw ] && bin/flaw scan . || crystal run lib/flaw/src/cli.cr -- scan .

docs: deps
	$(CRYSTAL) docs --output=docs/technical/api

clean:
	rm -rf docs/technical/api
	rm -rf .crystal
	rm -rf lib
	rm -rf bin


PREFIX ?= /usr/local
DESTDIR ?=
DATADIR ?= $(PREFIX)/share

install: docs
	install -d $(DESTDIR)$(DATADIR)/doc/crystal-dbus-native
	cp -r docs/* $(DESTDIR)$(DATADIR)/doc/crystal-dbus-native/
