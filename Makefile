PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SCRIPT := bin/codex-account

.PHONY: check lint fmt fmt-check test install uninstall help

help:
	@echo 'make check      Run lint, format check and tests'
	@echo 'make lint       Run shellcheck'
	@echo 'make fmt        Format with shfmt'
	@echo 'make test       Run the bats suite'
	@echo 'make install    Install to $(BINDIR) (override with PREFIX=)'
	@echo 'make uninstall  Remove from $(BINDIR)'

check: lint fmt-check test

lint:
	shellcheck --shell=bash --severity=style $(SCRIPT)

fmt:
	shfmt -i 2 -ci -w $(SCRIPT) tests

fmt-check:
	shfmt -i 2 -ci -d $(SCRIPT) tests

test:
	bats tests

install: $(SCRIPT)
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 $(SCRIPT) $(DESTDIR)$(BINDIR)/codex-account
	@echo 'Installed to $(DESTDIR)$(BINDIR)/codex-account'

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/codex-account
