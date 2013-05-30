#!/usr/bin/bash

DT=`date +%Y%m%d%p`
FILE=Backups/restore_$DT.sh
td dump / > $FILE
svn add $FILE

