# -----------------------------------------------------------------------------
#
# This is a bit modified code made by Johann Oberdorfer:
#   https://wiki.tcl-lang.org/page/A+Screenshot+Widget+implemented+with+TclOO
#
# Modified by Alex Plotnikov (https://aplsimple.github.io).
#
# See README.md for details.
#
# License: MIT.
#
# -----------------------------------------------------------------------------

package require Tk
package require TclOO
#lappend auto_path C:/ActiveTcl/lib/treectrl2.4.1
#lappend auto_path /usr/lib/treectrl2.4.1
package require treectrl
#lappend auto_path C:/ActiveTcl/lib/Img1.4.6
#lappend auto_path /usr/lib/tcltk/x86_64-linux-gnu/Img1.4.9
package require Img

package provide screenshooter 0.5

namespace eval ::screenshooter {

  variable solo [expr {[info exists ::argv0] && [file normalize $::argv0] eq \
    [file normalize [info script]]}]
  namespace export screenshot

  # this is a tk-like wrapper around the class,
  # so that object creation works like other Tk widgets

  proc screenshot {path args} {
    wm withdraw [toplevel $path]
    set path $path.scrshot
    set obj [ScreenShot create tmp $path {*}$args]
    rename $obj ::$path
    return $path
  }
}

# a canvas based object
oo::class create ::screenshooter::ScreenShot {

  constructor {path args} {
    my variable wcanvas
    my variable woptions
    my variable width
    my variable height
    my variable measure
    my variable shade

    my variable edge
    my variable drag
    my variable curdim

    array set woptions {
      -foreground black
      -font {Helvetica 14}
      -interval {10 50 100}
      -sizes {4 8 12}
      -showvalues  1
      -outline 1
      -grid 1
      -measure pixels
      -zoom 1
      -showgeometry 1
      -alpha 0.4
      -topmost 1
      -conffile "~/.config/screenshooter.conf"
      -geometry ""
      -savedir "."
      -wait "0 sec."
    }

    array set shade {
      small gray medium gray large gray
    }

    array set measure {
      what ""
      valid {pixels points inches mm cm}
      cm c mm m inches i points p pixels ""
    }

    set width 0
    set height 0

    array set edge {
      at 0
      left   1
      right  2
      top    3
      bottom 4
    }

    array set drag {}
    array set curdim {x 0 y 0 w 0 h 0}

    # --------------------------------
    ttk::frame $path -class ScreenShot
    # --------------------------------

    # for the screenshot window, depending on the os-specific window manager,
    # we'd like to have a semi-transparent window, which is on the very top of
    # all the windows stack and which is borderless (wm overrideredirect ...)
    #
    set t [winfo toplevel $path]
    wm withdraw $t
    catch {
      wm attributes $t -topmost 1
      wm overrideredirect $t 1
    }

    canvas $path.c \
        -width 600 -height 300 \
        -relief flat -bd 0 -background white \
        -highlightthickness 0

    set wcanvas $path.c
    pack $wcanvas -fill both -expand true

    bind $wcanvas <Configure>     "[namespace code {my Resize}] %W %w %h"
    bind $wcanvas <ButtonPress-1> "[namespace code {my DragStart}] %W %X %Y"
    bind $wcanvas <B1-Motion>     "[namespace code {my PerformDrag}] %W %X %Y"
    bind $wcanvas <Motion>  "[namespace code {my EdgeCheck}] %W %x %y"

    my AddMenu $wcanvas

    # $wcanvas xview moveto 0 ;  $wcanvas yview moveto 0

    # we must rename the widget command
    # since it clashes with the object being created

    set widget ${path}_
    rename $path $widget

    # start with default configuration
    foreach opt_name [array names woptions] {
      my configure $opt_name $woptions($opt_name)
    }

    # and configure custom arguments
    my configure {*}$args
    set showcmd "[namespace code {my RestoreOptions}]; pack $path -expand true -fill both ; wm deiconify $t"
    if {$::tcl_platform(platform) eq "windows"} {
      after 50 "$showcmd ; focus $wcanvas"
    } else {
      after 50 $showcmd
    }
    wm protocol $t WM_DELETE_WINDOW "[namespace code {my SaveOptions}]"
  }

  destructor {
    set w [namespace tail [self]]
    catch {bind $w <Destroy> {}}
    catch {destroy $w}
  }

  method cget { {opt "" }  } {
    my variable wcanvas
    my variable woptions

    if { [string length $opt] == 0 } {
      return [array get woptions]
    }
    if { [info exists woptions($opt) ] } {
      return $woptions($opt)
    }
    return [$wcanvas cget $opt]
  }

  method configure { args } {
    my variable wcanvas
    my variable woptions
    my variable measure
    my variable curdim

    if {[llength $args] == 0}  {

      # return all canvas options
      set opt_list [$wcanvas configure]

      # as well as all custom options
      foreach xopt [array get woptions] {
        lappend opt_list $xopt
      }
      return $opt_list

    } elseif {[llength $args] == 1}  {

      # return configuration value for this option
      set opt $args
      if { [info exists woptions($opt) ] } {
        return $woptions($opt)
      }
      return [$wcanvas cget $opt]
    }

    # error checking
    if {[expr {[llength $args]%2}] == 1}  {
      return -code error "value for \"[lindex $args end]\" missing"
    }

    # overwrite with new value and
    # process all configuration options...
    #
    array set opts $args

    foreach opt_name [array names opts] {
      set opt_value $opts($opt_name)

      # overwrite with new value
      if { [info exists woptions($opt_name)] } {
        set woptions($opt_name) $opt_value
      }

      # some options need action from the widgets side
      switch -- $opt_name {
        -font - -conffile - -savedir - -wait {}
        -sizes - -showvalues - -outline - -grid - -zoom {
          my Redraw
        }
        -foreground {
          my ReShade
          my Redraw
        }
        -measure {
          if {[set idx [lsearch -glob $measure(valid) $opt_value*]] == -1} {
            return -code error "invalid $option value \"$value\":\
                must be one of [join $measure(valid) {, }]"
          }
          set value [lindex $measure(valid) $idx]
          set measure(what) $measure($value)
          set woptions(-measure) $value
          my Redraw
        }
        -interval {
          set dir 1
          set newint {}
          foreach i $woptions(-interval) {
            if {$dir < 0} {
              lappend newint [expr {$i/2.0}]
            } else {
              lappend newint [expr {$i*2.0}]
            }
          }
          set woptions(-interval) $newint
          my Redraw
        }
        -showgeometry {
          if {![string is boolean -strict $opt_value]} {
            return -code error "invalid $option value \"$opt_value\":\
              must be a valid boolean"
          }

          $wcanvas delete geoinfo

          if {$opt_value} {
            set x 20
            set y 20
            foreach d {x y w h} {

              set w $wcanvas._$d
              catch { destroy $w }

              entry $w -borderwidth 1 -highlightthickness 1 -width 4 \
                -textvar [namespace current]::curdim($d) \
                -bg Orange

              $wcanvas create window $x $y -window $w -tags geoinfo

              bind $w <Return> "[namespace code {my PlaceCmd}]"

              # avoid toplevel bindings
              bindtags $w [list $w Entry all]
              incr x [winfo reqwidth $w]
            }
          }
        }
        -alpha {
          wm attributes [winfo toplevel $wcanvas] -alpha $opt_value
        }
        -topmost {
          wm attributes [winfo toplevel $wcanvas] -topmost $opt_value
        }
        -geometry {
          catch {
            wm geometry [winfo toplevel $wcanvas] $opt_value
            lassign [split $opt_value x+] - - curdim(x) curdim(y)
          }
        }
        default {
          # if the configure option wasn't one of our special one's,
          # pass control over to the original canvas widget
          #
          if {[catch {$wcanvas configure $opt_name $opt_value} result]} {
            return -code error $result
          }
        }
      }
    }
  }

  method display {} {
    my variable wcanvas
    set win [winfo toplevel $wcanvas]
    wm deiconify $win
    raise $win
    after idle "focus $wcanvas"
  }

  method hide {} {
    my variable wcanvas
    set win [winfo toplevel $wcanvas]
    wm withdraw $win
  }

  method unknown {method args} {
    my variable wcanvas

    # if the command wasn't one of our special one's,
    # pass control over to the original canvas widget
    #
    if {[catch {$wcanvas $method {*}$args} result]} {
      return -code error $result
    }
    return $result
  }

  method PlaceCmd {} {
    my variable wcanvas
    my variable curdim

    set win [winfo toplevel $wcanvas]
    wm geometry $win $curdim(w)x$curdim(h)+$curdim(x)+$curdim(y)
  }


  method ReShade {} {
    my variable wcanvas
    my variable woptions
    my variable shade

    set bg [$wcanvas cget -bg]
    set fg $woptions(-foreground)
    set shade(small)  [my Shade $bg $fg 0.15]
    set shade(medium) [my Shade $bg $fg 0.4]
    set shade(large)  [my Shade $bg $fg 0.8]
  }

  method Redraw {} {
    my variable wcanvas
    my variable woptions
    my variable width
    my variable height
    my variable measure

    $wcanvas delete ruler

    set width  [winfo width $wcanvas]
    set height [winfo height $wcanvas]

    my Redraw_x
    my Redraw_y

    if {$woptions(-outline) || $woptions(-grid)} {

      if {[tk windowingsystem] eq "aqua"} {
        # Aqua has an odd off-by-one drawing
        set coords [list 0 0 $width $height]
      } else {
        set coords [list 0 0 [expr {$width-1}] [expr {$height-1}]]
      }
      $wcanvas create rect $coords \
          -width 1 \
          -outline $woptions(-foreground) \
          -tags [list ruler outline]
    }

    if {$woptions(-showvalues) && $height > 20} {
      if {$measure(what) ne ""} {
        set m   [winfo fpixels $wcanvas 1$measure(what)]
        set txt "[format %.2f [expr {$width / $m}]] x\
            [format %.2f [expr {$height / $m}]] $woptions(-measure)"
      } else {
        set txt "$width x $height"
      }
      if {$woptions(-zoom) != 1} {
        append txt " (x$woptions(-zoom))"
      }
      $wcanvas create text 15 [expr {$height/2.}] \
          -text $txt \
          -anchor w -tags [list ruler value label] \
          -fill $woptions(-foreground)
    }
    $wcanvas raise large
    $wcanvas raise value
  }

  method Redraw_x {} {
    my variable wcanvas
    my variable woptions
    my variable width
    my variable height
    my variable measure
    my variable shade

    foreach {sms meds lgs} $woptions(-sizes) { break }
    foreach {smi medi lgi} $woptions(-interval) { break }
    for {set x 0} {$x < $width} {set x [expr {$x + $smi}]} {
      set dx [winfo fpixels $wcanvas \
          [expr {$x * $woptions(-zoom)}]$measure(what)]
      if {fmod($x, $lgi) == 0.0} {
        # draw large tick
        set h $lgs
        set tags [list ruler tick large]
        if {$x && $woptions(-showvalues) && $height > $lgs} {
          $wcanvas create text [expr {$dx+1}] $h -anchor nw \
              -text [format %g $x]$measure(what) \
              -tags [list ruler value]
        }
        set fill $shade(large)
      } elseif {fmod($x, $medi) == 0.0} {
        set h $meds
        set tags [list ruler tick medium]
        set fill $shade(medium)
      } else {
        set h $sms
        set tags [list ruler tick small]
        set fill $shade(small)
      }
      if {$woptions(-grid)} {
        $wcanvas create line $dx 0 $dx $height -width 1 -tags $tags \
            -fill $fill
      } else {
        $wcanvas create line $dx 0 $dx $h -width 1 -tags $tags \
            -fill $woptions(-foreground)
        $wcanvas create line $dx $height $dx [expr {$height - $h}] \
            -width 1 -tags $tags -fill $woptions(-foreground)
      }
    }
  }

  method Redraw_y {} {
    my variable wcanvas
    my variable woptions
    my variable width
    my variable height
    my variable measure
    my variable shade

    foreach {sms meds lgs} $woptions(-sizes) { break }
    foreach {smi medi lgi} $woptions(-interval) { break }
    for {set y 0} {$y < $height} {set y [expr {$y + $smi}]} {
      set dy [winfo fpixels $wcanvas \
          [expr {$y * $woptions(-zoom)}]$measure(what)]
      if {fmod($y, $lgi) == 0.0} {
        # draw large tick
        set w $lgs
        set tags [list ruler tick large]
        if {$y && $woptions(-showvalues) && $width > $lgs} {
          $wcanvas create text $w [expr {$dy+1}] -anchor nw \
              -text [format %g $y]$measure(what) \
              -tags [list ruler value]
        }
        set fill $shade(large)
      } elseif {fmod($y, $medi) == 0.0} {
        set w $meds
        set tags [list ruler tick medium]
        set fill $shade(medium)
      } else {
        set w $sms
        set tags [list ruler tick small]
        set fill $shade(small)
      }
      if {$woptions(-grid)} {
        $wcanvas create line 0 $dy $width $dy -width 1 -tags $tags \
            -fill $fill
      } else {
        $wcanvas create line 0 $dy $w $dy -width 1 -tags $tags \
            -fill $woptions(-foreground)
        $wcanvas create line $width $dy [expr {$width - $w}] $dy \
            -width 1 -tags $tags -fill $woptions(-foreground)
      }
    }
  }

  method Resize {W w h} {
    my variable wcanvas
    my variable curdim

    set curdim(w) $w
    set curdim(h) $h

    my Redraw
  }

  method Shade {orig dest frac} {
    my variable wcanvas

    if {$frac >= 1.0} {return $dest} elseif {$frac <= 0.0} {return $orig}
    foreach {oR oG oB} [winfo rgb $wcanvas $orig] \
        {dR dG dB} [winfo rgb $wcanvas $dest] {
          set color [format "\#%02x%02x%02x" \
          [expr {int($oR+double($dR-$oR)*$frac)}] \
          [expr {int($oG+double($dG-$oG)*$frac)}] \
          [expr {int($oB+double($dB-$oB)*$frac)}]]
          return $color
        }
  }

  method EdgeCheck {w x y} {
    my variable edge

    set edge(at) 0
    set cursor ""
    if {$x < 4 || $x > ([winfo width $w] - 4)} {
      set cursor sb_h_double_arrow
      set edge(at) [expr {$x < 4 ? $edge(left) : $edge(right)}]
    } elseif {$y < 4 || $y > ([winfo height $w] - 4)} {
      set cursor sb_v_double_arrow
      set edge(at) [expr {$y < 4 ? $edge(top) : $edge(bottom)}]
    }
    $w configure -cursor $cursor
  }

  method DragStart {w X Y} {
    my variable drag

    set drag(X) [expr {$X - [winfo rootx $w]}]
    set drag(Y) [expr {$Y - [winfo rooty $w]}]
    set drag(w) [winfo width $w]
    set drag(h) [winfo height $w]
    my EdgeCheck $w $drag(X) $drag(Y)

    raise $w
    focus $w
  }

  method PerformDrag {w X Y} {
    my variable edge
    my variable drag
    my variable curdim

    set curdim(x) [winfo rootx $w]
    set curdim(y) [winfo rooty $w]

    set win [winfo toplevel $w]

    if {$edge(at) == 0} {
      set dx [expr {$X - $drag(X)}]
      set dy [expr {$Y - $drag(Y)}]
      wm geometry $win +$dx+$dy
    } elseif {$edge(at) == $edge(left)} {
      # need to handle moving root - currently just moves
      set dx [expr {$X - $drag(X)}]
      set dy [expr {$Y - $drag(Y)}]
      wm geometry $win +$dx+$dy
    } elseif {$edge(at) == $edge(right)} {
      set relx   [expr {$X - [winfo rootx $win]}]
      set width  [expr {$relx - $drag(X) + $drag(w)}]
      set height $drag(h)
      if {$width > 5} {
        wm geometry $win ${width}x${height}
      }
    } elseif {$edge(at) == $edge(top)} {
      # need to handle moving root - currently just moves
      set dx [expr {$X - $drag(X)}]
      set dy [expr {$Y - $drag(Y)}]
      wm geometry $win +$dx+$dy
    } elseif {$edge(at) == $edge(bottom)} {
      set rely   [expr {$Y - [winfo rooty $win]}]
      set width  $drag(w)
      set height [expr {$rely - $drag(Y) + $drag(h)}]
      if {$height > 5} {
        wm geometry $win ${width}x${height}
      }
    }
  }

  method AddMenu {wcanvas} {

    if {[tk windowingsystem] eq "aqua"} {
      set CTRL    "Command-"
      set CONTROL Command
    } else {
      set CTRL    Ctrl+
      set CONTROL Control
    }

    set m $wcanvas.menu

    menu $m -tearoff 0

    if {$::tcl_platform(platform) eq "windows"} {
      set dsbl "-state disabled"  ;# buggy in Windows, let it show only Ctrl+s
    } else {
      set dsbl ""
    }
    $m add command -label "Create Screenshot..." \
      -accelerator ${CTRL}s -underline 7 {*}$dsbl \
      -command "[namespace code {my ScreenShotCmd}]"

    $m add separator

    $m add checkbutton -label "Keep on Top" \
      -underline 8 -accelerator "t" \
      -variable [namespace current]::woptions(-topmost) \
      -command "[namespace code {my configure}] -topmost $[namespace current]::woptions(-topmost)"
    bind $wcanvas <Key-t> [list $m invoke "Keep on Top"]

    $m add checkbutton -label "Show Grid" \
      -accelerator "d" -underline 8 \
      -variable [namespace current]::woptions(-grid) \
      -command "[namespace code {my configure}] -grid $[namespace current]::woptions(-grid)"

    $m add checkbutton -label "Show Geometry" \
      -accelerator "g" -underline 5 \
      -variable [namespace current]::woptions(-showgeometry) \
      -command "[namespace code {my configure}] -showgeometry $[namespace current]::woptions(-showgeometry)"

    set m1 [menu $m.opacity -tearoff 0]
    $m add cascade -label "Opacity" -menu $m1 -underline 0
    for {set i 10} {$i <= 100} {incr i 10} {
      set aval [expr {$i/100.}]
      $m1 add radiobutton -label "${i}%" -value $aval \
        -variable [namespace current]::woptions(-alpha) \
        -command "[namespace code {my configure}] -alpha $[namespace current]::woptions(-alpha)"
    }

    set m2 [menu $m.wait -tearoff 0]
    $m add cascade -label "Wait" -menu $m2 -underline 0
    foreach i {0 1 2 3 5 7 10 15 20 30} {
      $m2 add radiobutton -label "${i} sec." \
        -variable [namespace current]::woptions(-wait) \
        -command "[namespace code {my configure}] -wait $[namespace current]::woptions(-wait)"
    }

    bind $wcanvas <Key-t> [list $m invoke "Keep on Top"]
    bind $wcanvas <Key-d> [list $m invoke "Show Grid"]
    bind $wcanvas <Key-g> [list $m invoke "Show Geometry"]
    bind $wcanvas <$CONTROL-s> "[namespace code {my ScreenShotCmd}]"

    $m add separator
    $m add command -label "Exit" -accelerator "Esc" \
      -command "[namespace code {my SaveOptions}]"
    bind $wcanvas <Escape> "[namespace code {my SaveOptions}]"

    if {[tk windowingsystem] eq "aqua"} {
      # aqua switches 2 and 3 ...
      bind $wcanvas <Control-ButtonPress-1> [list tk_popup $m %X %Y]
      bind $wcanvas <ButtonPress-2> [list tk_popup $m %X %Y]
    } else {
      bind $wcanvas <ButtonPress-3> [list tk_popup $m %X %Y]
    }

  }

  method ScreenShotCmd {} {
    my variable woptions
    my variable wcanvas
    my variable curdim

    set wait $woptions(-wait)
    set wait [string range $wait 0 [string first " " $wait]-1]
    my hide
    after [expr {50+$wait*1000}]
    if { [catch {package require treectrl}] != 0 ||
              [llength [info commands loupe]] == 0 } {
      return -code error "tktreectrl loupe command is not available."
    }

    set capture_img [image create photo \
                -width $curdim(w) -height $curdim(h)]
    set zoom 1
    set loupe_ctr_x [expr {$curdim(x) + $curdim(w) / 2}]
    set loupe_ctr_y [expr {$curdim(y) + $curdim(h) / 2}]
    # ----------------------------------------------------------------------------
    after 50 \
      "loupe $capture_img $loupe_ctr_x $loupe_ctr_y $curdim(w) $curdim(h) $zoom"
    after 50
    update
    after 50
    # ----------------------------------------------------------------------------

    # finally, write image to file and we are done...
    set filetypes {
      {"PNG Images" .png}
      {"All Image Files" {.png .gif}}
    }
    set re {\.(png|gif)$}
    set LASTDIR $woptions(-savedir)
    set file [tk_getSaveFile \
      -parent $wcanvas -title "Save Image to File" \
      -initialdir $LASTDIR -filetypes $filetypes]
    if {$file ne ""} {
      if {![regexp -nocase $re $file -> ext]} {
        set ext "png"
        append file ".${ext}"
      }
      if {[catch {$capture_img write $file \
      -format [string tolower $ext]} err]} {
        tk_messageBox -title "Error Writing File" \
          -parent $wcanvas -icon error -type ok \
          -message "Error writing to file \"$file\":\n$err"
      }
      set woptions(-savedir) [file dirname $file]
      if {!$woptions(-topmost)} {my SaveOptions; return}
    }
    wm deiconify [winfo toplevel $wcanvas]
    image delete $capture_img
  }

  method SaveOptions {} {
    my variable woptions
    my variable wcanvas
    set w [winfo toplevel $wcanvas]
    catch {file mkdir [file dirinfo $woptions(-conffile)]}
    catch {
      set chan [open $woptions(-conffile) w]
      puts $chan {[options]}
      foreach opt {alpha grid geometry showgeometry topmost savedir wait} {
        if {$opt eq "geometry"} {
          set val [wm geometry $w]
        } else {
          set val $woptions(-$opt)
        }
        puts $chan "$opt=$val"
      }
      close $chan
    }
    if {$::screenshooter::solo} {
      exit 0
    } else {
      my hide
    }
  }

  method RestoreOptions {} {
    my variable woptions
    my variable wcanvas
    if {![file exists $woptions(-conffile)]} return
    set w [winfo toplevel $wcanvas]
    set chan [open $woptions(-conffile)]
    set conf [read $chan]
    close $chan
    foreach line [split $conf \n] {
      foreach opt {alpha grid geometry showgeometry topmost savedir wait} {
        if {[string first $opt= $line]==0} {
          set val [string range $line [string length $opt]+1 end]
          my configure -$opt $val
        }
      }
    }
  }

}
if {$::screenshooter::solo} {
  wm withdraw .
  screenshooter::screenshot .scrnshot -background LightYellow -foreground Green
}
