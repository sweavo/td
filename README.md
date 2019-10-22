# How to use td

td is designed to be used on the commandline to maintain a todo list. It supports an interactive 
mode and single-shot mode.

td only takes one command-line option, `-f` (more later) but for now, here's how to work td
interactively.

## Simple td session

	foofoo:demo sweavo$ ../td -f .
	PICKLE_FILE = /Users/sweavo/Source/td/demo/.pytask.pickle
	Warn: could not load /Users/sweavo/Source/td/demo/.pytask.pickle.
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	================================================================================
	td> add demonstrate todo
	demo
	td> add show adding
	show
	td> add set something to done
	sets
	td> ls
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	show adding                                                        -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	================================================================================
	td> done show
	td> ls
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	show adding                                                        Done   0.00 X
	================================================================================
	td> expunge
	td> ls
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	================================================================================
	td> ^D<EOF>
	foofoo:demo sweavo$ 

## How `-f` works

A little like git, td will search from the current directory up to the root for a `.pytask.pickle`
file to use. If none is found, then it will use (or create) the `.pytask.pickle` file in your home
directory.  The intended use here is that you mostly use one global todo list for yourself, but 
sometimes you are working in a particular project directory where you'd like to keep a more 
specific list. To create such a local list, use `td -f .` and a `.pytask.pickle` file will be 
created in the current dir. This can be checked in to source control if desired. From then on,
whenever you run td in that directory or any descendent, you will get that local list.

	foofoo:demo sweavo$ td ls
	PICKLE_FILE = /Users/sweavo/Source/td/demo/.pytask.pickle
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	================================================================================

	foofoo:demo sweavo$ cd sub/dir/
	foofoo:dir sweavo$ td ls
	PICKLE_FILE = /Users/sweavo/Source/td/demo/.pytask.pickle
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	================================================================================

The same picklefile is used even when you navigate to a subdir

	foofoo:dir sweavo$ td -f . ls
	PICKLE_FILE = /Users/sweavo/Source/td/demo/sub/dir/.pytask.pickle
	Warn: could not load /Users/sweavo/Source/td/demo/sub/dir/.pytask.pickle.
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	================================================================================

Using `-f .` points td to the current dir. Here a new, empty database is created and
listed.

	foofoo:dir sweavo$ td add subdir
	PICKLE_FILE = /Users/sweavo/Source/td/demo/sub/dir/.pytask.pickle
	subd
	foofoo:dir sweavo$ td ls
	PICKLE_FILE = /Users/sweavo/Source/td/demo/sub/dir/.pytask.pickle
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	subdir                                                             -.--   4.00  
	================================================================================

Now, without `-f` option, td finds the local `.pytask.pickle` first.

	foofoo:dir sweavo$ cd ..
	foofoo:sub sweavo$ td ls
	PICKLE_FILE = /Users/sweavo/Source/td/demo/.pytask.pickle
	================================================================================
	todo (development version)
	--------------------------------------------------------------------------------
	demonstrate todo                                                   -.--   4.00  
	sets: set something to done                                        -.--   4.00  
	================================================================================
	foofoo:sub sweavo$ 

But if we go back up above our local file, we find the original list again.

We can specify a directory using `-f` and the `.pytask.pickle` file in that directory will be 
used/created, regardless of whether there are more local `.pytask.pickle` files.

We can specify a filename using `-f` and that file will be used/created, regardless of whether
there are more local files. NOTE that such a file will not be found by the default `td` unless
its name is `.pytask.pickle`.  You will have to use `-f` every time you want to use that
file.

Finally, if you want the default not to be your home directly, set the environment variable
`TD_PICKLE_PATH` to the name of the directory you wish to keep your default picklefile in.

