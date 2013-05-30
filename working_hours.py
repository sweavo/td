#!/usr/bin/python -tt
# ex: set tabstop=4 expandtab:
#
# $Id: working_hours.py 179 2013-05-29 22:52:54Z sweavo $
#
"""
    Module to handle calculations of the number of hours available before a 
    deadline.
    
    The working day is regarded as being 0900 to 1800 with one hour lunch 
    ending before 1300.
    
    working_hours is the key function. The deadline ought to have a time 
    component of zero (it may work with other times but has not been tested)
    and the from_time might or might not have a time component. If it does, 
    then the hour has a different effect depending on its value t:
    00:00 - 09:00 credit is given for the 8 hour day from 0900-1800, plus the 
                  time between t and 0900.
    09:00 - 13:00 credit is given for the 4 hours between 1400 and 1800, plus
                  the time between t and 1300.
    13:00 - 18:00 credit is given for the time between t and 18:00
    18:00 ...     no credit is given for the day, but the clock effectively 
                  stops ticking until tomorrow. This represents unaccounted 
                  overtime.

"""

import datetime

CLOSE_OF_BUSINESS = 18

def parse_date( text ):
    """ accept many formats and return a datetime object. 

        yyyymmdd
        yyyymm
        mmdd
        dd/mm/yyyy
        dd-mm-yyyy

        all can be shorter, leaving the year or month to default.
    """
    if "-" in text:
        delim = "-"
    else:
        delim = "/"

    if delim not in text:
        format = "%Y%m%d"
        if len( text ) == 1:
            text = '0' + text
        if len( text ) == 2:
            text = '%02d%s' % ( datetime.datetime.today().month, text )
        if len( text ) == 4:
            text = '%04d%s' % ( datetime.datetime.today().year, text )
        if len( text ) == 6:
            text = '%s%02d' % ( text, datetime.datetime.today().day )

    else:
        format = "%d/%m/%Y"
        text = text.split( delim )
        if len( text ) == 1:
            text.append( str( datetime.datetime.today().month ) )
        if len( text ) == 2:
            text.append( str( datetime.datetime.today().year ) )
        text = '/'.join( text )

    return datetime.datetime.strptime( text , format )

def working_hours_till( deadline ):
    """ calculate 
    """
    return working_hours( datetime.datetime.today(), deadline )

def working_hours( from_time, deadline ):
    """ calculate the working hours left before deadline. Deadline is treated
        as zero hour on the given date.
        
        Hours remaining are calculated as 8 hours for every whole weekday
        between from_time and deadline, plus the number of hours remaining
        between from_time and close of business (unless from_time is a weekend
        in which case no credit is given for current date)
    """
    days = (deadline - from_time).days # Number of days between a and b # TODO inclusive or ex?
    # remove weekends
    num_wkends = days // 7
    # if dayofweek (start) > dayofweek(end) add one more weekend
    if from_time.weekday() > deadline.weekday():
        num_wkends += 1
    
    days -= 2*num_wkends # actually subtract the weekends
    hours = days * 8
    if from_time.hour: # if a time is provided, use it in the calculation
        if from_time.hour >= 18:
            pass # we ignore time after CoB
        else:
            hours += (18-from_time.hour)
        if from_time.hour<13: # allow for lunchtime
            hours-=1
    return hours

import unittest

class TestParse( unittest.TestCase ):

    def testNumeric8( self ):
        """ yyyymmdd """
        a = parse_date( "20121224" )
        self.assertEqual( a.day, 24 )
        self.assertEqual( a.month, 12 )
        self.assertEqual( a.year, 2012 )

    def testNumeric6( self ):
        """ yyyymm """
        a = parse_date( "201212" )
        self.assertEqual( a.day, datetime.datetime.today().day )
        self.assertEqual( a.month, 12 )
        self.assertEqual( a.year, 2012 )

    def testNumeric4( self ):
        """ mmdd """
        a = parse_date( "1224" )
        self.assertEqual( a.day, 24 )
        self.assertEqual( a.month, 12 )
        self.assertEqual( a.year, datetime.datetime.today().year )

    def testJustDay( self ):
        a = parse_date("11")
        self.assertEqual( a.day , 11 )
        self.assertEqual( a.month , datetime.datetime.today().month )
        self.assertEqual( a.year , datetime.datetime.today().year )


    def testThisYearSlash( self ):
        a = parse_date("1/11")
        self.assertEqual( a.day , 1 )
        self.assertEqual( a.month , 11 )
        self.assertEqual( a.year , datetime.datetime.today().year )

    def testThisYearMinus( self ):
        a = parse_date("1-11")
        self.assertEqual( a.day , 1 )
        self.assertEqual( a.month , 11 )
        self.assertEqual( a.year , datetime.datetime.today().year )

    def testThisYearConcat( self ):
        a = parse_date("1101")
        self.assertEqual( a.day , 1 )
        self.assertEqual( a.month , 11 )
        self.assertEqual( a.year , datetime.datetime.today().year )


class TestMath( unittest.TestCase ):

    def test1DayIs8Hours( self):
        a = parse_date("1/11")
        b = parse_date("2/11")
        res = working_hours( a, b )
        self.assertEqual( res, 8 )

    def test2DaysIs16Hours( self ):
        a = parse_date("1/11")
        b = parse_date("3/11")
        res = working_hours( a, b )
        self.assertEqual(res, 16 )

    def test2DaysMinus2HoursIs14Hours( self ):    
        # from 11am to the day after tomorrow = 14 hours (2 days - 2 hours)
        a = parse_date("1/11")
        a = a.replace( hour = 11 )
        b = parse_date("3/11")
        res = working_hours( a, b )
        self.assertEqual(res,14 )
    
    def testMondayToMondayIs40Hours( self ):
        # one week => one weekend = 40 hours
        today = datetime.datetime.today()
        mon1 = today.day - today.weekday()
        mon2 = 7 + today.day - today.weekday()
        if mon1 < 1:
            mon1 += 7
            mon2 += 7
        while mon2 > 30:
            mon1 -= 7
            mon2 -= 7
        a = parse_date("%d/%d" % ( mon1, today.month ) ) # monday
        b = parse_date("%d/%d" % ( mon2, today.month ) ) # monday
        res = working_hours( a, b )
        self.assertEqual( res, 5*8 )

    def testThursdayToMondayIs16Hours( self ):
        # less than one week, spanning a weekend
        # one week => one weekend = 40 hours
        today = datetime.datetime.today()
        thu = 3 + today.day - today.weekday()
        mon = 7 + today.day - today.weekday()
        if thu < 1:
            thu += 7
            mon += 7
        while mon > 30:
            thu -= 7
            mon -= 7
        a = parse_date("%d/%d" % ( thu, today.month ) ) # monday
        b = parse_date("%d/%d" % ( mon, today.month ) ) # monday
        res = working_hours( a, b )
        self.assertEqual( res, 2*8 )

    def testAfterHours( self ):
        # it's after close of business today, and deadline is day after tomorrow
        # that means we have one whole day.
        a = parse_date("1/11") # monday
        a = a.replace( hour = 19 )
        b = parse_date("3/11") # wednesday
        res = working_hours( a, b )
        self.assertEqual(res,8)

    def testInEarly( self ):
        # it's before start of business today, and deadline is tomorrow
        # that means we have extra time
        a = parse_date("1/11") # monday
        a = a.replace( hour = 7 )
        b = parse_date("2/11") # wednesday
        res = working_hours( a, b )
        self.assertEqual( res, 10 )


        # Test with start date in the weekend
        # Test with end date in the weekend

# If we run this module, it tests itself
if __name__ == "__main__":
    unittest.main()