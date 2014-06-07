# -*- mode: Makefile; -*-
# ex set tabstop=4 noexpandtabs

INST_DIR=/usr/local/bin

PHONIES=default install report test

GIT_DESCRIPTION=$(shell git describe --dirty='-modified')-$(shell git rev-parse --abbrev-ref HEAD)

.PHONY: $(PHONIES)

default:
	@echo targets: $(PHONIES)

install: 
	cp -v working_hours.py $(INST_DIR) 
	sed 's/^GIT_DESCRIPTION=.*/GIT_DESCRIPTION="$(GIT_DESCRIPTION)"/' td >$(INST_DIR)/td

report:
	td tree /rte > Reports/report_`date +%Y%m%d`.html 

test:
	(cd test; ./test.sh)

backup:
	./backup.sh

describe:
	echo $(GIT_DESCRIPTION)

