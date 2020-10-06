 The *screenshooter.tcl* is a Tcl/Tk small utility allowing to make screenshots with a grid window covering a target spot of the screen.

 ----

 This is a bit modified code made by Johann Oberdorfer:
 
   [A Screenshot Widget implemented with TclOO](https://wiki.tcl-lang.org/page/A+Screenshot+Widget+implemented+with+TclOO)

 Modified by Alex Plotnikov:
 
   [aplsimple.github.io](https://aplsimple.github.io)

 ----

 The modification is the *screenshooter.tcl* that:

     * restores the opacity in Linux at start
     * saves and restores options: -grid, -showgeometry, -topmost
     * saves and restores also window's geometry and directory to save
     * gets the focus at start, to enable Ctrl+s in Windows without clicking
     * disables "Save" menu item in Windows, because it's buggy (Ctrl+s works)
     * makes png by default
     * doesn't exit after canceling the Save dialog
     * closes wish on saving a screenshot
     * closes wish on exiting with Alt+F4 and Escape keys

 The options are saved to *~/.config/screenshooter.conf*.

 ----

 There is also an executable [screenshooter](https://github.com/aplsimple/screenshooter/releases/download/screenshooter.v0.1/screenshooter)  for Linux. Pitifully, Windows' *screenshooter.exe* doesn't properly recognize the screen resolution.

 ----

 Lisense: MIT.
