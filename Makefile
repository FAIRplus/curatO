# config
MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

# Run `make all` to create a new CURATO release:
# - download the latest build of ROBOT
# - download the latest versionos of IAO and BFO
# - create curato-edit.owl from the template
# - merge curato-edit.owl with imports to create curato-merged.owl
# - reason over curato-merged.owl to create curato.owl
# - clean build files

# If you wish to keep build/robot.jar, run `make release` instead.

# ===============================
#           VARIABLES
# ===============================

SHELL   := /bin/bash
OBO	:= http://purl.obolibrary.org/obo
DEV	:= $(OBO)/curato/dev
ROBOT	:= java -jar build/robot.jar

# release vars
TODAY	:= $(shell date +%Y-%m-%d)
TS	:= $(shell date +'%d:%m:%Y %H:%M')

# directories
SRC = src/ontology


# ===============================
#             MAIN TASK
# ===============================

# run `make all` or `make release` to make a new release
# `make all` will remove the build dir with ROBOT on completion
all: clean

### Directories
#
# This is a temporary place to put things.
build:
	mkdir -p $@

# ===============================
#             ROBOT
# ===============================

# download the most recent build of ROBOT
build/robot.jar: | build
	@echo "Getting ROBOT" && \
	curl -L https://github.com/ontodev/robot/releases/download/v1.7.0/robot.jar > ./build/robot.jar

# get IAO and BFO:
build/bfo-iao: | build
	@echo "Getting IAO and BFO latest versions" &&
	curl -L http://purl.obolibrary.org/obo/bfo.owl   > ./ontology-source-files/bfo.owl 
	curl -L http://purl.obolibrary.org/obo/iao.owl   > ./ontology-source-files/iao.owl

clean: | release
	@echo "Removing build files" && \
	rm -rf build

# ===============================
#           CURATO TASKS
# ===============================

# generate curatO-edit from template file:
build/template: | build/robot.jar build
	@echo "Creating from Template $< to $@" && \
	$(ROBOT) template --template src/curatO-curation-ontology-capabilities-all-classes-2020-09-07.csv  \
	 --prefix "curato: https://fairplus-project.eu/ontologies/curato/" \
	 --ontology-iri "https://fairplus-project.eu/ontologies/curato/" \
	 --output ./build/curatO-edit.owl 
# 	$(ROBOT) annotate \
#   	 --input ./build/curatO-edit.owl \
# 	 --ontology-iri "$(OBO)/curatO.owl" \
# 	 --version-iri "$(OBO)/curatO/$(TODAY)/curatO.owl" \
# 	 --annotation owl:versionInfo "$(TODAY)" \
# 	 --annotation-file src/annotations.ttl


# merge components to generate curatO-merged
build/merge: build/robot.jar build
	@echo "Merging $< to $@" && \
	$(ROBOT)  merge --input ./build/curatO-edit.owl  \
	--input ./ontology-source-files/bfo.owl  \
	--input ./ontology-source-files/iao.owl  \
	--output ./build/curatO-merged-with-imports.owl

# 	annotate \
# 	--ontology-iri "$(OBO)/curato/curatO-merged.owl" \
# 	--version-iri "$(OBO)/curato/$(TODAY)/curatO-merged.owl" \
# 	--annotation owl:versionInfo "$(TODAY)" \


# reason over curatO-merged to generate curat
build/reason: build/robot.jar build
	@echo "Reasoning $< to $@" && \
	$(ROBOT) reason \
	--input ./build/curatO-merged-with-imports.owl \
	--reasoner HermiT \
	--exclude-tautologies all \
	--output ./build/curatO-reasoned.owl

build/annotate: build/robot.jar build
	@echo "Adding Metadata $< to $@" && \
	$(ROBOT) annotate \
	--input ./build/curatO-reasoned.owl \
	--ontology-iri "$(OBO)/curatO.owl" \
	--version-iri "$(OBO)/curatO/$(TODAY)/curatO.owl" \
	--annotation owl:versionInfo "$(TODAY)" \
	--annotation-file src/annotations.ttl \
	--output ./build/curatO.owl
# 	--output ./build/$(TODAY)/curatO.owl

release: build/template build/merge build/reason build/annotate
	@echo "A new release is made"

