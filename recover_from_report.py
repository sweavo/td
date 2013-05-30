#!/usr/bin/python -tt
#
# $Id: $
#
# Recover as much td data as possible from a report file

import sys

from xml.dom import minidom

def getText( node ):
    if node.nodeName == '#text':
        return node.nodeValue
    else:
        return ''.join( [ getText( c ) for c in node.childNodes ] )

def descend( table_node, dep = 0 ):
    in_item = False
    for row in table_node.childNodes:
        cols = []
        for column in row.childNodes:
            if column.localName == 'th':
                continue
            if column.localName == 'td':
                cols.append( column )
        if len(cols) == 0:
            pass
        elif len(cols) == 3:
            id = getText( cols[0] )
            text = getText( cols[1] )
            remain = getText( cols[2] )
            if in_item:
                print "  " * dep, "cd .."
            print "  " * dep, "adc ", text
            print "  " * dep, "ren .", id
            print "  " * dep, "remain", remain,"."
            in_item=True
        elif len(cols) == 2:
            for c in cols[1].childNodes:
                if c.localName == 'table':
                    descend( c, dep+1 )
    if in_item:
        print "  " * dep, "cd .."

doc = minidom.parse( sys.stdin )

for c in doc.childNodes:
    if c.localName == "html":
        html = c

for c in html.childNodes:
    if c.localName == "body":
        body = c

for c in body.childNodes:
    if c.localName == "table":
        print "#/usr/bin/bash"
        print "td -f bibble batch <<EOF"
        print "reset"
        descend( c )
        print "EOF"

