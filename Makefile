# -*- mode: Makefile; -*-
# ex set tabstop=4 noexpandtabs

INST_DIR=/usr/local/bin

PHONIES=default install report test

.PHONY: $(PHONIES)

default:
	@echo targets: $(PHONIES)

install: 
	cp -v working_hours.py $(INST_DIR) 
	cp -v td $(INST_DIR)

report:
	td tree /rte > Reports/report_`date +%Y%m%d`.html 

test:
	(cd test; ./test.sh)

backup:
	./backup.sh
