#!/usr/bin/bash
set -o pipefail
set -e
set -u

# Test script for td
TEMP_ERR=.err.$$.tmp
TEMP_OUT=.out.$$.tmp

function test_td
{
    $TD -f ./test.pickle "$@" 2>$TEMP_ERR >$TEMP_OUT
}

## test subject
TD=$(cd ..; pwd -L )/td

## Bootstrap Tests

### Check that -f works. If not, we mustn't continue as we might scrub user data.  We can't use fgrep -q or we'll find the pipe closed and td will throw.
echo -n "Test 1: " 
if $TD -f ./minus-f-check.pickle ls | fgrep minus-f-check-ok
then
    echo "Pass."
else
    echo "FAIL. Stop."
    echo "(Hint: if you don't have colorama installed, you sadly need to do that before running tests)"
    exit 1
fi

### Remove (if present) the test's pickle file
rm -f test.pickle


there_were_failures=false

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
    there_were_failures=true
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
    there_were_failures=true
fi
cat $TEMP_ERR 1>&2

## Search for the picklefile in the current dir first
echo -n "Test 4.1: "
pushd test4/deeper >/dev/null
$TD ls >$TEMP_OUT 2>$TEMP_ERR
if fgrep -q "deeper item" $TEMP_OUT
then
    echo "Pass."
else 
    echo "FAIL."
    there_were_failures=true
fi
cat $TEMP_OUT
popd >/dev/null
 

## Search for the picklefile in the current dir first
echo -n "Test 4.2: "
pushd test4/deeper-empty >/dev/null
$TD ls >$TEMP_OUT 2>$TEMP_ERR
if fgrep -q "Item in test4 directory" $TEMP_OUT
then
    echo "Pass."
else 
    echo "FAIL."
    there_were_failures=true
fi
cat $TEMP_OUT
popd >/dev/null


# Tidy up
### Remove (if present) the test's pickle file
rm -f test.pickle
find . -name .err.\*.tmp -delete -o -name .out.\*.tmp -delete


# Report
if $there_were_failures
then
    echo "There were FAILURES. Stop."
    exit 1
else
    echo "Everything was OK."
fi
