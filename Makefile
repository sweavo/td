# -*- mode: Makefile; -*-
# ex set tabstop=4 noexpandtabs

INST_DIR=/usr/local/bin

PHONIES=default install report test

GIT_DESCRIPTION=$(shell git describe --dirty='-modified')

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
