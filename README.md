# Mach4ATC

These are the changes I made to my Mach4 setup to control ATC and tool probing.  Directory structure mimicks the
Mach4 layout.

- Screens/AvidCNC_ATC.set: A modified version of the AvidCNC default screenset, which includes a new "Tool Change"
tab.  There are scripts associated with the new buttons, panel, etc.  It is unfortunately not well commented at
the moment
- Modules/mcAutoTool.lua: a script that ships with Mach4.  I made a few small tweaks (annotated in comments) for
my needs (adjusted Z offset, take abs() of tool length)
- Profiles/AvidCNC/Modules/ToolChangePositions.lua: The ATC module, which contains code for m6, replacing, probing
and loading tool data from the csv.
- Profiles/AvidCNC/Modules/ToolChangePositions.csv: the CSV holding tool names, numbers and pocket offsets
- Profiles/AvidCNC/Macros/m6.mcs: m6 macro, which basically just calls into our ATC m6 module

There are some unrelated changes in the screenset since I have been tweaking, and there are various hard-coded
file paths in the scripts (because I was too lazy to figure out how lua does relative paths).  So I would not
use these scripts directly, but instead use them as reference or inspiration.  Goodluck!
