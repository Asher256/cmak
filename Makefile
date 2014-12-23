#
# Makefile pour installer cmak.
#
# Ce script a besoin des programmes suivants:
#     - gzip
#     - install
#     - rm
#     - rmdir
#
# Auteur: Asher256 <contact@asher256.com>
#

PREFIX=/usr/local

all: help

help:
	@echo "Instructions pour installer ou desinstaller le logiciel."
	@echo ""
	@echo "Installer cmak:    make install"
	@echo "Desinstaller cmak: make uninstall"
	@echo ""

install:
	install -d $(PREFIX)/bin $(PREFIX)/share/cmak $(PREFIX)/share/doc/cmak
	install -m 755 cmak.pl $(PREFIX)/bin/cmak
	install -m 644 cmak.cfg.default $(PREFIX)/share/cmak/cmak.cfg
	install -m 644 cmak.cfg.skel $(PREFIX)/share/doc/cmak

uninstall:
	rm -f $(PREFIX)/bin/cmak $(PREFIX)/share/cmak/cmak.cfg $(PREFIX)/share/doc/cmak/*
	rmdir $(PREFIX)/share/cmak $(PREFIX)/share/doc/cmak

