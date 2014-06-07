#!/usr/bin/python -tt
# ex: set tabstop=4 expandtab:
#
# $Id: td 180 2013-05-29 23:48:15Z sweavo $
#
""" Task list program.

AVAILABLE VERBS:

Adding / Editing Tasks:

    add TEXT:
        Add a new todo with text TEXT below the current task.

    adc TEXT:
        Add (see above) followed by cd (see below) to the new task.

    boost PATH [...]:
        Boost the named task(s) to the start of the list

    bump PATH [...]:
        Bump the named task(s) to the end of the list

    by DATE PATH:
        set the deadline for a task
        
    defer DATE PATH:
        set the start date of a task

    done/undone PATH ...:
        Mark item at each PATH as done or remove mark. Default PATH is current.

    ed PATH text:
        Replace the text of the identified todo item.

    expunge:
        Remove all todos marked as Done from the current task.

    ic:
        Integrity Check. Run this if you are told that a valid path is not
        valid.

    move SRCPATH DSTPATH:
        Move the task identified by SRCPATH to be a child of that identified by
        DSTPATH. NOTE: does not change the referenced task's ID. For that, use
        ren.

    mv SRCPATH DSTPATH:
        Synonym for move.

    mmv SRCPATH ... DSTPATH
        Move multiple items

    ren SRCPATH ID:
        set the ID on the task indicated by SRCPATH. NOTE: cannot move items,
        only set their ID. For that, use mv.

    remain TIME PATH:
        Set the remaining estimated time on a task, or X to remove estimate.

Moving About:

    cd PATH:
        change current task to task at PATH.

    popd:
        Change to the directory at the top of the stack, removing it

    pushd PATH:
        Put the current directory on the top of the stack, and change to the
        specified PATH. If PATH is omitted, perform a pds command (see below)

    rotd:
        Put current directory on BOTTOM of stack and popd.

    swd:
        Switch directory with the top of the directory stack.

    zoom PATH:
        Recursively navigate to the biggest child of the biggest child of the 
        identified task.
        
Display:

    leaves PATH:
        Show the todo items below the PATH that don't themselves have children
        
    ls PATH:
        List the todo items in the current curdir

    clear:
        clear the screen

    dirs / pds:
        Print directory stack

    pwd:
        Print current task

    show PATH:
        Print the full, unformatted text of the indicated Task.

Reports:

    dump:
        Dump entire database to stdout as a shell script
        (use on commandline, e.g. td dump > restore.sh )

Other Modes:
    batch:
        Useful for restoring dumps, read commands from stdin with no editing 
        or readline capability.

    interactive:
        This is the default action if no verb is supplied. Enters interactive
        mode where verbs and operands are taken from stdin with history and 
        GNU readline.

    help:
        this text

    reset:
        totally don't use this. it resets the database irretrievably

"""
# All code must come after the docstring for __doc__ to work.
GIT_DESCRIPTION="(development version)"

from copy import copy
import os
import pickle
try:
    import readline
except ImportError:
    readline=None
import sys
import time

import working_hours

ANSI_RED = "\033[31;1m"
ANSI_GREEN = "\033[32;1m"
ANSI_BRIGHT = "\033[1m"
ANSI_RESET = "\033[0m"

VERBS={
    "add": ["TEXT"], 
    "adc": ["TEXT"], 
    "batch": [],
    "boost": ["PATH"],
    "bump": ["PATH"],
    "by": ["DATE", "PATH"],
    "cd": ["PATH"],
    "clear": [],
    "defer": ["DATE", "PATH"],
    "dirs": [],
    "done": ["PATH"],
    "dump": [],
    "ed": ["PATH", "TEXT"],
    "expunge": [],
    "help": [],
    "ic": [],
    "interactive": [],
    "ls": [],
    "mv": ["SRCPATH", "DSTPATH"],
    "mmv": ["SRCPATHS", "DSTPATH"],
    "pds": [],
    "popd": [],
    "pushd": ["PATH"],
    "pwd": [],
    "ren": ["SRCPATH", "ID"],
    "remain": ["TIME", "PATH"],
    "reset": [],
    "rotd": [],
    "show": ["PATH"],
    "swd": [],
    "undone": ["PATH"],
}

EXE_NAME="td"
TASK_TEXT_WIDTH=63
PROMPT=EXE_NAME+'> '
ID_WIDTH=4

CONTEXT="Default"
if os.environ.has_key('TD_CONTEXT'):
    CONTEXT = os.environ['TD_CONTEXT']

DEFAULT_REMAIN=4.0

# global_db is used for readline to be able to hook into the Todo list.
global_db = None

def warn( s ):
    sys.stderr.write( "Warn: %s\n" % s )

def error( s ):
    sys.stderr.write( "Error: %s\n" % s )


def pretty_time( seconds ):
    thresholds = [ ( 60, 'm'), ( 60, 'h' ), ( 24, 'd' ), ( 7, 'w' ) ]
    n = seconds
    ret = 's'
    for thres,unit in thresholds:
        ret = '%d%s' % ( n%thres, ret )
        n = n // thres
        if n == 0:
            return ret
        else:
            ret = "%s, %s" % ( unit, ret )

def chomp_word( sentence ):
    try:
        space = sentence.index(" ")
    except ValueError:
        return sentence,""
    return ( sentence[:space], sentence[space+1:].strip() )

def banner( ch=None):
    if ch is None:
        ch = "="
    return ANSI_GREEN + ( ch * 80 ) + ANSI_RESET

def auto_complete( text, state ):
    """ state seems to want to increment until we return None """
    #print text,state
    verb, operand = chomp_word(text)
    if operand == "":
        count = 0
        candidates={}
        for k in VERBS:
            if (k + "          ")[:len(text)] == text:
                if state == count:
                    return k
                else:
                    count+=1
        return None
    else:
        if state==0:
            return "<parameter>"
        else:
            return None

class el(object):
    """ An XML element for writing reports """
    def __init__(s, tag, content=None ):
        s.content = content
        s.tag = tag
    def __str__(s):
        if s.content is None:
            return "<%s/>" % s.tag
        elif isinstance(s.content,list):
            result = "<%s>" % s.tag
            for c in s.content:
                result+="\n" + str( c )
            result +="\n</%s>" % s.tag
        else:
            result = "<%s>%s</%s>" % (s.tag, s.content, s.tag )
        return result

class TaskDatabase(object):

    def __init__(s):
        """ Initialize a new TaskDatabase containing the root task. """
        s.root=Task( s, "root", "/ Task List" )
        s.root.parent=s.root
        s.curdir=s.root
        # Dirstack is the stack of directories for pushd and popd.
        # 
        s.dirstack=[]
        s.path=[]

    def add(s, text, path=None):
        """ Add a task to the current dir """
        if path is None:
            path = "."
        return s.get(path).add( text )

    def get(s, path, origin=None):
        """ resolve a path and return the task found there. """
        if origin is None:
            origin=s.curdir
        if path == '':
            return origin
        else:
            plist = path.split('/')
            head = plist[0]
            tail = '/'.join(plist[1:])
            if head=='': # path started with /
                return s.get( tail, s.root )
            elif head=='.':
                return s.get( tail, origin )
            elif head=='..':
                return s.get( tail, origin.parent )
            elif origin.get_child( head ):
                return s.get( tail, origin.get_child( head ) )
            else:
                return None

    def cd(s, path):
        """ resolve path and change current directory to it. """
        tgt = s.get( path )
        if tgt is None:
            error ("Invalid Path")
            return False
        else:
            s.curdir = tgt
            return True

    def pds(s,option=None):
        """ print the directory stack """
        ret = ''
        l=len(s.dirstack)
        for i,x in enumerate( s.dirstack ):
            ret+="%d:%s "%(l-i,x.get_path())
            if option == '-v':
                ret += x.text + "\n"
        print ret

    def pushd(s, path):
        """ push directory onto stack and change """
        olddir = s.curdir
        if s.cd( path ):
            s.dirstack.append( olddir )
            s.pds()

    def popd(s):
        """ pop directory from stack """
        if len(s.dirstack) == 0:
            print "No more paths to pop."
        else:
            s.cd( s.dirstack.pop().get_path() )

    def rotd(s, num=None):
        """ pushd and unqueue current dir from BOTTOM of stack 
        
            num is the index from the top of the stack or negative num is 
            from the top of the stack.
        """
        if isinstance(num,int):
            pass
        elif num.isdigit():
            num = int(num)
            if num < 0:
                num = len(s.dirstack) + num
        else:
            num = len(s.dirstack)
        for x in range(0, num):
            s.dirstack.insert( 0, s.curdir )
            s.popd( )

    def swd(s, num):
        """ switch directory (exchange current directory with the one on the
            top of the stack, or with one by index if specfied
        """
        if isinstance(num,int):
            pass
        elif num.isdigit():
            num = int(num)
        else:
            num = 1
        if len(s.dirstack) < num:
            error ("Dir Stack has %d element(s)." % len(s.dirstack))
            return False
        else:
            tmp = s.dirstack[-num]
            s.dirstack[-num] = s.curdir
            s.curdir=tmp
            return True

    def ls(s, path='.' ):
        """ resolve path and display the resulting task """
        tgt = s.get( path )
        if tgt is None:
            error ("Invalid Path")
        else:
            tgt.ls()

    def dump(s):
        print "td batch <<EOF"
        print "reset"
        s.root.dump()
        print "EOF"

class Task(object):

    def __init__(s, parent, text, category=None, prio=1, due=None):
        """ initialize a new task under a parent """
        s.parent = parent
        # We magic the ID. Our parent will check it and modify if necessary.
        s.set_id( text )
        s.text = text
        s.prio = prio
        s.due = due
        s.done = None
        s.children = []
        s.remain = None
        s.created = time.time()
        s.deadline = None
        s.defer = None
        s.expanded = False

    def add(s, text):
        """ create and add a child task given its text """
        if text.strip() == "":
            return None
        return s.add_child( Task(s, text) )

    def add_child(s, t, id=None):
        """ add an existing child task to a task, adjusting its ID if necessary """
        # Allow caller to suggest the ID
        if id is not None:
            t.set_id(id)
        else:
            t.set_id(t.get_id()) # force a validation of ID
        
        orig_id=t.get_id() # the desired ID
        count = 0
        while s.get_child( t.get_id() ) is not None: # now disambiguate.
            count = count + 1
            sc = str(count)
            wid=len(sc)
            t.set_id( orig_id[:ID_WIDTH-wid] + sc )
        # the task's ID is unique amongst its new siblings. Move it.
        s.children.append( t )
        t.parent = s
        return t

    def boost( s ):
        """ move self to start of parent's list of children """
        s.parent.children = [s] + [ c for c in s.parent.children if c is not s ]

    def bump( s ):
        """ move self to end of parent's list of children """
        s.parent.children = [ c for c in s.parent.children if c is not s ]
        s.parent.children.append( s )

    def calc_deadline( s ):
        """ set deadline to date/time dt """
        if s.deadline is None:
            return s.parent.calc_deadline()
        else:
            return s.deadline

    def calc_remain(s, override=True):
        """ return the remain calculated recursively. 
        
            override:   return the user-set remain if it's more than the
                        calculated remain. Default True 
        """
        if s.done is not None:
            return 0.0
        else:
            found = False
            total = 0.0
            for c in s.children:
                if c.done is None:
                    found = True
                    total += c.calc_remain()
            if found:
                if s.remain is None or ((s.remain < total) or not override):
                    return total
                else:
                    return s.remain
            else:
                if s.remain is not None:
                    return s.remain 
                else:
                    return DEFAULT_REMAIN

    def count_tasks(s):
        """ return the number of live tasks this task represents """
        if len(s.children)==0:
            return 1
        else:
            return sum( c.count_tasks() for c in s.children )

    def dump(s, depth = None):
        """ recursive dump of the commands necessary to reproduce this task
            and all its descendents
        """
        INDENT = "  "
        if depth is None:
            depth = 0
        print INDENT * depth + "# " + s.get_path()
        if s.get_path() == '/':
            print "ed / " + s.text
        else:
            print INDENT * depth + "adc %s" % s.text
            depth = depth + 1
            print INDENT * depth + "ren . %s" % s.get_id()
            if s.remain is not None:
                print INDENT * depth + "remain %.2f" % s.remain
        for c in s.children:
            c.dump( depth )
        if s.get_path() != '/':
            if s.done is not None:
                print INDENT * depth + "done ."
            else:
                print INDENT * depth + "cd .."
            depth -= 1
            print INDENT * depth + "# End of %s. " % s.get_path()

    def expand( self ):
        self.expanded = True

    def expunge(s):
        """ remove all children marked as done """
        s.children = [c for c in s.children if c.done is None]

    def format(s, task_text_width=None, highlight=None, with_path=None, prefix=None):
        """ format this task on one line for output """
        if task_text_width is None:
            task_text_width=TASK_TEXT_WIDTH
        if with_path is None:
            with_path=False
        if prefix is None:
            prefix = ''

        if s.deadline is not None:
            task_text_width -= 10 # width of "mm/dd XXX "
        if highlight is None:
            highlight=False
        ret =""
        if with_path:
            ret += s.get_path()
            task_text_width -= len(s.get_path())
        if not s.match_id(s.text):
            formatted_id = "%s: " % s.get_id()
            ret += formatted_id
            task_text_width -= len( formatted_id )
        ret = prefix + ret
        task_text_width -= len( prefix )

        ret += ("%-" + str(task_text_width) + "s ") % s.text[:task_text_width]
        
        if s.deadline is not None:
            ret += s.deadline.strftime( "%d/%m " ) + ("%03d " % working_hours.working_hours_till( s.deadline ) )

        calcd_remain = s.calc_remain(False)
        tail = ''
        if s.done is None:
            if s.remain is None:
                ret += "   -.--"
            else:
                if calcd_remain > (s.remain * 1.02): # effort overrun in red
                    ret += ANSI_RED
                    tail = ANSI_RESET
                elif calcd_remain < (s.remain * 0.75): # effort underrun by 75% green
                    ret += ANSI_GREEN
                    tail = ANSI_RESET
                ret += "% 7.2f" % s.remain
        else:
            ret += "   Done"
        ret += "% 7.2f " % calcd_remain
        ret += tail
        if len(s.children)>0 and s.done is not None:
            ret += "*"
        elif len(s.children)>0:
            ret += "+"
        elif s.done is not None:
            ret += "X"
        else:
            ret += " "
        
        if highlight:
            ret = ANSI_BRIGHT + ret + ANSI_RESET
        return ret

    def get_child(s, key):
        """ retrieve the child with the given key, or return None """
        for c in s.children:
            if c.match_id(key):
                return c
        # not found
        return None

    def get_id(s):
        """ retrieve the (tidied?) ID of this task """
        if isinstance(s.task_id, int):
            return "#%03d" % s.task_id
        else:
            return s.task_id

    def get_path(s):
        """ return the absolute path of this task """
        if s.parent == s:
            return "/"
        else:
            return s.parent.get_path() + str(s.task_id) + "/"

    def integrity_check(s, recurse=True):
        """ re-write the list of children so that they have valid IDs. Recurse """
        msgs = []
        childlist = copy(s.children)
        del s.children[:]
        for c in childlist:
            s.add_child(c)
            if recurse:
                msgs.extend( c.integrity_check( True ) )
        return msgs

    def leaves( s ):
        """ descend this task and show its leaf descendents """
        if len([ x for x in s.children if x.done is None] ) == 0:
            print s.format( TASK_TEXT_WIDTH, with_path=True )
        else:
            for c in s.children:
                if c.done is None:
                    c.leaves()

    def ls( s, prefix="" ):
        """ show this task and its children if any """
        if prefix is "":
            depth = s.print_lineage( s )
            print banner('-')
        undones = [ c for c in s.children if c.done is None ]
        dones =  [ c for c in s.children if c.done is not None ]
        for d in undones:
            print d.format(TASK_TEXT_WIDTH, highlight=True, prefix=prefix )
            if d.expanded:
                d.ls( prefix + '    /' )
        for d in dones:
            print d.format(TASK_TEXT_WIDTH, highlight=False, prefix=prefix )
        if prefix is "":
            print banner()

    def match_id(s, m):
        """ return whether the given id identifies this Task """
        id = s.get_id()
        return m[:len(id)].lower() == id.lower()

    def print_lineage( s, highlight=None ):
        if s.parent == s: # then I am root
            print banner()
            print ("%s td %s") % ( s.text, GIT_DESCRIPTION )
            return ""
        else:
            dep = s.parent.print_lineage( highlight )
            print dep + s.format(TASK_TEXT_WIDTH - len(dep), highlight==s )
            return "  " + dep

    def rm(s, id):
        """ remove the child identified by id """
        s.children.remove( s.get_child(id) )

    def set_id(s,id):
        """ set the task's ID. This function is concerned with validating and
            formatting the ID, but not with making sure the parent's index is
            correct.  That has to be the parent's concern.
            """
        if isinstance(id, int):
            s.task_id = "#%03d" % id
        else:
            id = id.replace(" ","").replace("/","").lower()[:ID_WIDTH]
            if id.isdigit():
                s.task_id = ("#%03d" % int(id) ) 
            else:
                s.task_id = id

    def set_remain(s, days):
        """ set the estimated time remaining on this task 
            Argument is number or None"""
        s.remain = days

    def set_text(s, text):
        """ set the text for the task """
        s.text = text

    def max_depth( s ):
        md = 1
        for c in s.children:
            if c.done is None:
                cmd = c.max_depth()
                if md <= cmd:
                    md = cmd + 1
        return md

    def unexpand( self ):
        self.expanded = False

    def zoom(s):
        """ descend recursively into the child with the most remaining time.
        """
        if len(s.children) == 0:
            return s
        else:
            min=s.calc_remain()
            max=0.0
            for c in s.children:
                r = c.calc_remain()
                if r > max:
                    result = c
                    max = r
                if r < min:
                    min = r
            if max == min:
                return s
            else:
                return result.zoom()

# assume no error
ret = 0

def execute_command( command_line ):
    """ one action upon the database. (which of course may be "interactive",
        in which case it loops and recurses on itself.
    """
    # We assume we will re-write the database after we're done with the command
    save = True

    # Wa assume we have successfully executed the command unless we hear otherwise
    success = True
    
    # break off the first word as our command
    command, operand = chomp_word( command_line )
    
    # See whether we can/should read the database
    if command[0] == '#': # Special case: skip comments
        save = False
        return True

    elif command == 'reset':
        print "Info: cleared TODO database."
        db=TaskDatabase()

    elif command == 'batch':
        pass # batch will attempt the load
        save = False

    elif command == 'interactive':
        pass # interactive will attempt the load
        save = False

    else:
        try:
            f=open(PICKLE_FILE,"rb")
            db=pickle.load(f)
            global_db = db
            f.close()
        except:
            warn( "could not load %s."%PICKLE_FILE )
            db=TaskDatabase()

    # Interpret the command
    if command == 'help':
        print __doc__

    elif command == 'add': # Add a task in the current curdir
        print db.add(operand).task_id

    elif command == 'adc': # Add task and change to it.
        db.cd( db.add( operand ).get_path() )

    elif command == 'batch':
        l = sys.stdin.readline() # we don't strip() it here, because then blank line terminates the while loop
        while l:
            if l.strip() != '':
                if not execute_command( l.strip() ):
                    success = False
                    break
            l = sys.stdin.readline()
        print "<EOF>"

    elif command == 'boost':
        success=True
        srcs=[]
        while success and len( operand.strip() ) > 0 :
            src_path, operand = chomp_word( operand )
            src = db.get( src_path )
            if src is None:
                error ("Invalid Path: %s" % src_path )
                success = False
            srcs.append( src )
        if success:
            for tgt in reversed( srcs ):
                tgt.boost()

    elif command == 'bump':
        success=True
        srcs=[]
        while success and len( operand.strip() ) > 0 :
            src_path, operand = chomp_word( operand )
            src = db.get( src_path )
            if src is None:
                error ("Invalid Path: %s" % src_path )
                success = False
            srcs.append( src )
        if success:
            for tgt in srcs:
                tgt.bump()

    elif command == 'by':
        date_text, path = chomp_word( operand )
        try:
            dt = working_hours.parse_date( date_text )
        except:
            error ("Invalid Date")
            return False
        tgt = db.get( path )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.deadline = dt

    elif command == 'cd':
        db.cd( operand )

    elif command == 'clear':
        print '\x1b[H\x1b[2J'

    elif command == 'defer':
        date_text, path = chomp_word( operand )
        try:
            dt = working_hours.parse_date( date_text )
        except:
            error ("Invalid Date")
            return False
        tgt = db.get( path )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.defer( dt )

    elif command == 'done':
        if operand == '':
            error ("Missing Path")
            success = False
        else:
            cd_dot_dot = False
            while operand != "":
                path, operand = chomp_word( operand )
                tgt = db.get( path )
                if tgt is None:
                    error ("Invalid Path (%s)" % path)
                    success = False
                else:
                    tgt.done=time.time()
                    if tgt == db.curdir:
                        cd_dot_dot = True
            if cd_dot_dot:
                db.cd('..')

    elif command == 'dump': # spit out the whole database as a program that re-creates it
        db.dump()

    elif command == 'ed': # edit the item at path to have text x
        path, text = chomp_word( operand )
        tgt = db.get( path )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.set_text( text )

    elif command == 'expand':
        tgt = db.get( operand )
        if tgt is None:
            error( "Invalid Path" )
            success = False
        else:
            tgt.expand()

    elif command == 'expunge':
        tgt = db.get( operand )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.expunge()

    elif command == 'ic':
        log =  db.root.integrity_check()
        for l in log:
            print l
        print "check complete."

    elif command == 'interactive':
        execute_command( 'ls' )
        try:
            l = raw_input( PROMPT )
            if l == '\04':
                l = None
        except EOFError:
            l = None
        while l is not None:
            if l.strip() != '':
                success = execute_command( l.strip() ) and success
            try:
                l = raw_input( PROMPT )
                if l == '\04':
                    l = None
            except EOFError:
                l = None
        print "<EOF>"

    elif command == 'leaves': # No command line==Display the tasks
        tgt = db.get(operand)
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.leaves()

    elif command == 'ls': # No command line==Display the tasks
        tgt = db.get(operand)
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            tgt.ls()

    elif command == 'mv' or command == 'move':
        src_path, text = chomp_word( operand )
        src = db.get( src_path )
        if src is None:
            error ("Invalid Source Path")
            success = False
        elif src.parent == src:
            error ("Can't move the root!")
            success = False
        else:
            tgt_path, text = chomp_word( text )
            tgt = db.get( tgt_path )
            if tgt is None:
                error ("Invalid Target Path")
                success = False
            else:
                print "from: %s" % src.get_path() 
                src.parent.rm( src.get_id() )
                tgt.add_child( src )
                print "to: %s" % src.get_path() 
    elif command == 'mmv': # multi move
        srcs = []
        while success and len( operand.strip() ) > 0 :
            src_path, operand = chomp_word( operand )
            src = db.get( src_path )
            if len( operand.strip() ) > 0:
                # queue up the task to move
                if src is None:
                    error ("Invalid Source Path")
                    success = False
                elif src.parent == src:
                    error ("Can't move the root!")
                    success = False
                srcs.append( src )
            else:
                # Now move the things to the target
                tgt = src
                if tgt is None:
                    error ("Invalid Target Path")
                    success = False
                else:
                    if len( srcs ) == 0:
                        error( "Missing Destination Path" )
                        success = False
                    else:
                        for src in srcs:
                            src_path = src.get_path() 
                            src.parent.rm( src.get_id() )
                            tgt.add_child( src )
                            print "from: %s to %s." % ( src_path, src.get_path() )
        
    elif command == 'pds':
        db.pds( operand )

    elif command == 'dirs': # synonym for pds
        db.pds( operand )

    elif command == 'pushd':
        if operand == '':
            db.pds()
        else:
            db.pushd( operand )

    elif command == 'popd':
        db.popd()
        db.pds()
        db.ls()

    elif command == 'pwd':
        print db.curdir.get_path()

    elif command == 'reset': # We've already done the action but don't want to land in the else:
        pass

    elif command == 'remain':
        days, path = chomp_word( operand )
        tgt = db.get( path )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            if days == "X":
                tgt.set_remain( None )
            else: 
                try: 
                    tgt.set_remain( float( days ) )
                except ValueError:
                    error( "Remain TIME should be float or X." )

    elif command == 'ren':
        srcname, remains = chomp_word( operand )
        dstname, remains = chomp_word( remains )
        tgt = db.get( srcname )
        tgt2 = db.get( dstname )
        if tgt is None:
            error ("Invalid Path")
            success = False
        elif tgt2 is not None:
            print "Destination ID '%s' already exists" % dstname
            success = False
        else:
            tgt.set_id( dstname )
            tgt.parent.integrity_check(False)

    elif command == 'rotd':
        db.rotd( operand )
        db.ls()

    elif command == 'show':
        tgt = db.get( operand )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            print tgt.text

    elif command == 'swd':
        if db.swd(operand):
            db.pds()
            db.ls()

    elif command == 'undone':
        cd_dot_dot = False
        while operand != "":
            path, operand = chomp_word( operand )
            tgt = db.get( path )
            if tgt is None:
                error ("Invalid Path (%s)" % path)
                success = False
            else:
                tgt.done = None

    elif command == 'unexpand':
        tgt = db.get( operand )
        if tgt is None:
            error( "Invalid Path" )
            success = False
        else:
            tgt.unexpand()
    elif command == 'version':
        print GIT_DESCRIPTION
    elif command == 'zoom':
        tgt = db.get( operand )
        if tgt is None:
            error ("Invalid Path")
            success = False
        else:
            db.cd( tgt.zoom().get_path() )

    else:
        error ("unknown verb %s."%command)
        success = False
    if save:
        f=open(PICKLE_FILE,"wb")
        pickle.dump(db,f)
        f.close()

    return success

# First, tame the command line
PICKLE_PATH="~"
if os.environ.has_key('TD_PICKLE_PATH'):
    PICKLE_PATH = os.environ['TD_PICKLE_PATH']
PICKLE_FILE = os.path.expanduser( os.path.join( PICKLE_PATH, ".pytask.pickle") )
if len(sys.argv) > 1 and sys.argv[1] == '-f':
    # Specify the pickle file
    sys.argv.pop(1)
    file_name = sys.argv.pop(1)
    if os.path.isfile( file_name ):
        # if the provided string is a path to a file, use it
        PICKLE_FILE = file_name
    elif os.path.isfile( os.path.expanduser( os.path.join( PICKLE_PATH, file_name ) ) ):
        # if the provided string is the name of a file present in the PICKLE-PATH, use it
        PICKLE_FILE = os.path.expanduser( os.path.join( PICKLE_PATH, file_name ) )
    elif os.path.isdir( file_name ):
        # if the provided string is a dir, use the .pytask.pickle file in that dir
        PICKLE_PATH = file_name
        PICKLE_FILE = os.path.expanduser( os.path.join( PICKLE_PATH, ".pytask.pickle") )
    elif os.path.isdir( os.path.dirname( file_name ) ):
        # if the provided path is a non-existent file in an existing dir, use that path and file.
        PICKLE_PATH = os.path.dirname( file_name )
        PICKLE_FILE = os.path.expanduser( file_name )
    elif os.path.basename( file_name ) == file_name:
        # if the provided string is just a filename, then use that filename in the default location
        PICKLE_FILE = os.path.expanduser( os.path.join( PICKLE_PATH, file_name) )
    else:
        # good luck! We leave the error reporting to the code that tries to open the file.
        PICKLE_FILE = os.path.expanduser( os.path.join( PICKLE_PATH, ".pytask.pickle") )

sys.stderr.write( "PICKLE_FILE = %s\n" % PICKLE_FILE )

HISTORY_FILE = os.path.expanduser( PICKLE_PATH + "/.pytask.history" )

# if we are not given a commandline, then go into interactive mode
if len(sys.argv)==1:
    command_line='interactive'
else:
    command_line=' '.join(sys.argv[1:])

# Set up readline in case we need it
try:
    readline.set_completer( auto_complete )
    readline.parse_and_bind( "tab: complete" )
    readline.read_history_file( HISTORY_FILE )
except:
    pass

# then execute it
execute_command( command_line )
try:
    readline.write_history_file( HISTORY_FILE )
except:
    pass
# End of logic

