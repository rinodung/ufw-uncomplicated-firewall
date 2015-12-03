SRCS     = src/ufw $(wildcard src/*.py)
POTFILES = locales/po/ufw.pot
TMPDIR   = ./tmp
EXCLUDES = --exclude='.bzr*' --exclude='*~' --exclude='*.swp' --exclude='*.pyc' --exclude='debian' --exclude='ubuntu'
VERSION  = $(shell egrep '^ufw_version' ./setup.py | cut -d "'" -f 2)
SRCVER   = ufw-$(VERSION)
TARBALLS = ../tarballs
TARSRC   = $(TARBALLS)/$(SRCVER)
TARDST   = $(TARBALLS)/$(SRCVER).tar.gz
PYFLAKES = $(TMPDIR)/pyflakes.out
PYFLAKES_EXE = pyflakes

ifndef $(PYTHON)
export PYTHON=python
endif

all:
	# Use setup.py to install. See README for details
	exit 1

install: all

translations: $(POTFILES)
$(POTFILES): $(SRCS)
	xgettext -d ufw -L Python -o $@ $(SRCS)

mo:
	make -C locales all

test:
	./run_tests.sh -s -i $(PYTHON)

unittest:
	./run_tests.sh -s -i $(PYTHON) unit

coverage:
	# No python3 coverage yet
	#$(PYTHON) ./tests/unit/runner.py
	python -m coverage run ./tests/unit/runner.py

coverage-report:
	# No python3 coverage yet
	#$(PYTHON) ./tests/unit/runner.py
	python -m coverage report --show-missing --omit="tests/*"

syntax-check: clean
	$(shell mkdir $(TMPDIR) && $(PYFLAKES_EXE) src 2>&1 | grep -v "undefined name '_'" > $(PYFLAKES))
	cat "$(PYFLAKES)"
	test ! -s "$(PYFLAKES)"

man-check: clean
	$(shell mkdir $(TMPDIR) 2>/dev/null)
	for manfile in `ls doc/*.8`; do \
		page=$$(basename $$manfile); \
		manout=$(TMPDIR)/$$page.out; \
		echo "Checking $$page for errors... "; \
		PAGER=cat LANG='en_US.UTF-8' MANWIDTH=80 man --warnings -E UTF-8 -l doc/$$page >/dev/null 2> "$$manout"; \
		cat "$$manout"; \
		test ! -s "$$manout" || exit 1; \
		echo "PASS"; \
	done; \

check: syntax-check man-check test unittest

# These are only used in development
clean:
	rm -rf ./build
	rm -rf ./staging
	rm -rf ./tests/testarea ./tests/unit/tmp
	rm -rf $(TMPDIR)
	rm -f ./locales/mo/*.mo
	rm -f ./tests/unit/*.pyc ./tests/*.pyc ./src/*.pyc
	rm -rf ./tests/unit/__pycache__ ./tests/__pycache__ ./src/__pycache__
	rm -rf ./.coverage
	rm -f ./ufw               # unittest symlink

evaluate: clean
	mkdir -p $(TMPDIR)/ufw/usr $(TMPDIR)/ufw/etc
	UFW_SKIP_CHECKS=1 $(PYTHON) ./setup.py install --home=$(TMPDIR)/ufw
	PYTHONPATH=$(PYTHONPATH):$(TMPDIR)/ufw/lib/python $(PYTHON) $(TMPDIR)/ufw/usr/sbin/ufw version
	cp ./examples/* $(TMPDIR)/ufw/etc/ufw/applications.d
	# Test with:
	# PYTHONPATH=$$PYTHONPATH:$(TMPDIR)/ufw/lib/python $(PYTHON) $(TMPDIR)/ufw/usr/sbin/ufw ...
	# sudo sh -c "PYTHONPATH=$$PYTHONPATH:$(TMPDIR)/ufw/lib/python $(PYTHON) $(TMPDIR)/ufw/usr/sbin/ufw ..."

devel: evaluate
	cp -f ./tests/defaults/profiles/* $(TMPDIR)/ufw/etc/ufw/applications.d
	cp -f ./tests/defaults/profiles.bad/* $(TMPDIR)/ufw/etc/ufw/applications.d

debug: devel
	sed -i 's/DEBUGGING = False/DEBUGGING = True/' $(TMPDIR)/ufw/lib/python/ufw/util.py

tarball: syntax-check clean translations
	bzr export --format dir $(TARSRC)
	tar -zcv -C $(TARBALLS) $(EXCLUDES) -f $(TARDST) $(SRCVER)
	rm -rf $(TARSRC)

