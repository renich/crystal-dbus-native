SHELL = /bin/sh
.SHELLFLAGS := -ec
.ONESHELL:
.DELETE_ON_ERROR:
.SUFFIXES:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.DEFAULT_GOAL := all
.PHONY: all deps test check lint doc-check format docs install uninstall clean help

CRYSTAL  ?= crystal
SHARDS   ?= shards
CRSTLINT ?= crstlint
PREFIX   ?= /usr/local
DESTDIR  ?=
DATADIR  ?= $(PREFIX)/share
DOCDIR   ?= $(DATADIR)/doc/crystal-dbus-native
BINDIR   := bin
AMEBA    := $(BINDIR)/ameba
FLAW     := $(BINDIR)/flaw
RST_FILES := $(wildcard *.rst) $(shell find docs -type f -name '*.rst' 2>/dev/null)

all: lint doc-check test ## Run static analysis, doc checks, and test suite

deps: $(AMEBA) $(FLAW) ## Install shard dependencies and build linter binaries

$(BINDIR):
	mkdir -p $@

$(AMEBA): | $(BINDIR)
	@if [ ! -f lib/ameba/src/cli.cr ]; then $(SHARDS) install; rm -f shard.lock; fi
	$(CRYSTAL) build lib/ameba/src/cli.cr -o $@

$(FLAW): | $(BINDIR)
	@if [ ! -f lib/flaw/src/cli.cr ]; then $(SHARDS) install; rm -f shard.lock; fi
	$(CRYSTAL) build lib/flaw/src/cli.cr -o $@

test: ## Execute the Crystal spec suite
	$(CRYSTAL) spec

check: all ## Run all verification gates (lint, doc-check, test)

lint: $(AMEBA) $(FLAW) ## Run Ameba and Flaw static analysis
	$(CRYSTAL) tool format --check src spec
	./$(AMEBA) --all
	./$(FLAW) scan .

doc-check: ## Lint reStructuredText documentation with crstlint and rstcheck
	@if command -v $(CRSTLINT) >/dev/null 2>&1; then $(CRSTLINT) -r .; fi
	@if command -v rstcheck >/dev/null 2>&1; then rstcheck $(RST_FILES); fi

format: ## Format all Crystal source and spec files
	$(CRYSTAL) tool format src spec

docs: ## Generate Crystal API documentation and Sphinx dirhtml suite
	$(CRYSTAL) docs --output=docs/technical/api
	$(MAKE) -C docs dirhtml

install: docs ## Install documentation into DESTDIR/DOCDIR
	install -d $(DESTDIR)$(DOCDIR)
	cp -r docs/* $(DESTDIR)$(DOCDIR)/

uninstall: ## Remove installed documentation from DESTDIR/DOCDIR
	rm -rf $(DESTDIR)$(DOCDIR)

clean: ## Remove build artifacts, generated docs, and caches
	rm -rf docs/technical/api docs/build .crystal lib $(BINDIR) shard.lock

help: ## Display available build targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
