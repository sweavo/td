#!/usr/bin/bash


# Test script for td
TEMP=.tmp.$$

function test_td
{
  $TD "$@" 2>$TEMP
}

## test subject
TD=../td


## Bootstrap Tests

### Check that -f works. If not, we mustn't continue as we might scrub user data
echo -n "Test 1: " 
if test_td -f ./minus-f-check.pickle "ls" | fgrep -q minus-f-check-ok
then
	echo "Pass."
else
	echo "FAIL. Stop."
	exit 1
fi
cat $TEMP 1>&2

### Remove (if present) the test's pickle file
rm -f test.pickle
TD="$TD -f ./test.pickle"


## Can we add an item and does it return an ID?
### we do this on a non-existent picklefile to see that we don't get a warning
### on stdout.
### check that td accepts command line in a single argv.
echo -n "Test 2: "
ID1=$(test_td "add this is my first test item")
if [ "$ID1" == "this" ]
then
  echo "Pass."
else
  echo "$ID1"
  echo "FAIL."
fi
cat $TEMP 1>&2

## If we add a second item does the ID bump up?
### also check that td accepts multiple spaces between verb and operand.
echo -n "Test 3: "
ID2=$(test_td "add  this is my second test item")
if [ "$ID2" == "thi1" ]
then
  echo "Pass."
else
  echo "FAIL."
fi
cat $TEMP 1>&2

