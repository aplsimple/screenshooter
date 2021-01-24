## What's that

The *screenshooter* is a Tcl/Tk small utility allowing to make screenshots with a grid window covering a target spot of the screen.

This is a bit modified code made by Johann Oberdorfer:
 
   [A Screenshot Widget implemented with TclOO](https://wiki.tcl-lang.org/page/A+Screenshot+Widget+implemented+with+TclOO)

<img src="https://aplsimple.github.io/en/tcl/screenshooter/files/screenshooter.png" class="media" alt="">

## Options

The result of the modification is *screenshooter.tcl* that:

  * restores the opacity in Linux at start
  * saves and restores options: -grid, -showgeometry, -topmost, -wait
  * saves and restores the window's geometry and the directory to save
  * sets a pause to wait before the screenshooting
  * gets the focus at start, to enable Ctrl+s in Windows without clicking
  * disables "Create Screenshot" menu item in Windows, as it's buggy
  * makes png by default
  * doesn't exit after canceling the Save dialog
  * if topmost, stays on the screen after saving a screenshot, otherwises exits
  * closes `wish` on exiting, incl. with Alt+F4 and Escape keys
  * can be used as a widget from Tcl/Tk code

The options are saved to *~/.config/screenshooter.conf*.

## Usage

Runs with the command:

     tclsh screenshooter.tcl

The `Img` and `treectrl` packages have to be installed to run it. In Debian Linux the packages are titled `libtk-img` and `tktreectrl`.

There are also executables:

  * [screenshooter for Linux 64bit](https://github.com/aplsimple/screenshooter/releases/download/screenshooter.v0.5/screenshooter) (8 Mb)

  * [screenshooter for Windows 64bit](https://github.com/aplsimple/screenshooter/releases/download/screenshooter_windows.v0.5/screenshooter.7z) (7 Mb)

The executables run as simply as:

     screenshooter
     screenshooter.exe

To change the screenshooter's position, just grab it with the mouse, then drag and drop it.

To change the screenshooter's size, grab its bottom or right side, then drag and drop it.

To make a screenshot:

  * in Windows: press Ctrl+s

  * in Linux: click it with the right button of mouse, then choose "Create Screenshot" from the popup menu

In the popup menu, change options of the screenshooter.

To make several screenshots at once, set "Keep on Top" option on.

To close the screenshooter:

  * in Windows: press Escape or Alt+F4 or choose "Exit" from the popup menu

  * in Linux: choose "Exit" from the popup menu

## Widget

The *screenshooter* package can be used in Tcl/Tk code to make the *screenshooter* widget.

The appropriate code may look like this:

     package require screenshooter
     # ...
     # call the widget
     if {[info exists ::widshot]} {
       $::widshot display
     } else {
       set ::widshot [screenshooter::screenshot .win.sshooter \
         -background LightYellow -foreground Green]
     }

where:

  * `::widshot` - variable for the widget's command
  * `$::widshot display` - shows the existing *screenshooter*
  * `.win.sshooter` - path to a toplevel window (to be created by *screenshooter*)

## Links

  * [Reference](https://aplsimple.github.io/en/tcl/screenshooter/screenshooter.html)

  * [Source](https://chiselapp.com/user/aplsimple/repository/screenshooter/download) (screenshooter.zip)

  * [screenshooter for Linux 64bit](https://github.com/aplsimple/screenshooter/releases/download/screenshooter.v0.5/screenshooter) (8 Mb)

  * [screenshooter for Windows 64bit](https://github.com/aplsimple/screenshooter/releases/download/screenshooter_windows.v0.5/screenshooter.7z) (7 Mb)

## License
 
MIT.
