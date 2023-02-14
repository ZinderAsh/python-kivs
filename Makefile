CXX=g++
CFLAGS=-g -Wall -Wextra -lm
CBUILDDIR=build/src
CPROGRAMDIR=build
CTESTDIR=tests
CSRCDIR=biocy/cpp
COBJECTS=$(CBUILDDIR)/Graph.o $(CBUILDDIR)/hashing.o $(CBUILDDIR)/KmerFinder.o $(CBUILDDIR)/GFA.o
CHEADERS=$(CSRCDIR)/node.hpp $(CSRCDIR)/doctest.h

.PHONY: clean clean-build clean-pyc clean-test coverage dist docs help install lint lint/flake8
.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

clean: clean-build clean-pyc clean-test clean-c ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

clean-c: ## clean files generated by C and C++
	rm -rf kmer_finder tests/test_biocy $(CBUILDDIR)

lint/flake8: ## check style with flake8
	flake8 biocy tests

lint: lint/flake8 ## check style

test: test-c test-py ## run C and Python tests

test-full: test-c test-py-full ## run ALL C and python tests, including slow tests

test-py: ## run tests quickly with the default Python
	pytest

test-py-full: ## run Python tests, including slow tests
	pytest --runslow

test-py-all: ## run tests on every Python version with tox
	tox

test-c: $(CTESTDIR)/test_biocy ## run C tests
	$(CTESTDIR)/test_biocy

coverage: ## check code coverage quickly with the default Python
	coverage run --source biocy -m pytest
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html

profile:
	python -m memory_profiler profiling/main.py

docs: ## generate Sphinx HTML documentation, including API docs
	rm -f docs/biocy.rst
	rm -f docs/modules.rst
	sphinx-apidoc -o docs/ biocy
	$(MAKE) -C docs clean
	$(MAKE) -C docs html
	$(BROWSER) docs/_build/html/index.html

servedocs: docs ## compile the docs watching for changes
	watchmedo shell-command -p '*.rst' -c '$(MAKE) -C docs html' -R -D .

release: dist ## package and upload a release
	twine upload dist/*

dist: clean kmer_finder.o ## builds source and wheel package
	python setup.py sdist
	python setup.py bdist_wheel
	ls -l dist

install: clean kmer_finder.o ## install the package to the active Python's site-packages
	python setup.py install --user

# C objects and programs

$(CBUILDDIR)/Graph.o: $(CSRCDIR)/Graph.cpp $(CSRCDIR)/Graph.hpp $(CSRCDIR)/node.hpp
	mkdir -p $(CBUILDDIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(CBUILDDIR)/KmerFinder.o: $(CSRCDIR)/KmerFinder.cpp $(CSRCDIR)/KmerFinder.hpp $(CBUILDDIR)/Graph.o
	mkdir -p $(CBUILDDIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(CBUILDDIR)/GFA.o: $(CSRCDIR)/GFA.cpp $(CSRCDIR)/GFA.hpp $(CBUILDDIR)/hashing.o
	mkdir -p $(CBUILDDIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(CBUILDDIR)/hashing.o: $(CSRCDIR)/hashing.cpp $(CSRCDIR)/hashing.hpp
	mkdir -p $(CBUILDDIR)
	$(CXX) $(CFLAGS) -c -o $@ $<

$(CTESTDIR)/test_biocy: $(CSRCDIR)/test_biocy.cpp $(COBJECTS) $(CHEADERS)
	mkdir -p $(CTESTDIR)
	$(CXX) $(CFLAGS) -o $@ $< $(COBJECTS) $(CHEADERS) -I.

biocy: $(CSRCDIR)/biocy.cpp $(COBJECTS) $(CHEADERS)
	mkdir -p $(CPROGRAMDIR)
	$(CXX) $(CFLAGS) -o $(CPROGRAMDIR)/$@ $< $(COBJECTS) $(CHEADERS) -I.