#!/usr/bin/bash


# Test script for td
TEMP_ERR=.err.$$.tmp
TEMP_OUT=.out.$$.tmp

function test_td
{
  $TD -f ./test.pickle "$@" 2>$TEMP_ERR >$TEMP_OUT
}

## test subject
TD=../td


## Bootstrap Tests

### Check that -f works. If not, we mustn't continue as we might scrub user data
echo -n "Test 1: " 
if $TD -f ./minus-f-check.pickle "ls" 2>/dev/null | fgrep -q minus-f-check-ok
then
	echo "Pass."
else
	echo "FAIL. Stop."
	exit 1
fi

### Remove (if present) the test's pickle file
rm -f test.pickle


## Can we add an item and does it return an ID?
### we do this on a non-existent picklefile to see that we don't get a warning
### on stdout.
### check that td accepts command line in a single argv.
echo -n "Test 2: "
test_td "add this is my first test item" 
read ID1 < $TEMP_OUT
if [ "$ID1" == "this" ]
then
  echo "Pass."
else
  echo "$ID1"
  echo "FAIL."
fi
cat $TEMP_ERR 1>&2

## If we add a second item does the ID bump up?
### also check that td accepts multiple spaces between verb and operand.
echo -n "Test 3: "
test_td "add  this is my second test item"
read ID2 < $TEMP_OUT
if [ "$ID2" == "thi1" ]
then
  echo "Pass."
else
  echo "FAIL."
fi
cat $TEMP_ERR 1>&2

