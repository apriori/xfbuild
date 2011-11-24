== About xfBuild ==
    This is a port/fork of xfBuild to the D2 programming langauge.
    
    xfBuild was originally made by Tomasz Stachowiak. (http://h3.gd)
    Original Project Homepage: http://bitbucket.org/h3r3tic/xfbuild
    
    xfBuild was ported to D2 by Andrej Mitrovic.
    Port Project Homepage: http://github.com/AndrejMitrovic/xfBuild
    
    ** This is an alpha release, expect bugs. File them when you find them! **

== Building Requirements ==
    - DMD v2.056+ compiler. Download DMD from: http://www.digitalmars.com/d/download.html
      Usage instructions: http://d-programming-language.org/dmd-windows.html

    - Windows only: WindowsAPI bindings library, get it here:
        http://dsource.org/projects/bindings/wiki/WindowsApi
      
      Install it next to the xfBuild dir:
        .\xfBuild
        .\WindowsAPI
        
    Tested on XP SP3 and Lubuntu, x86.
      
== Building ==
    Windows: Run build.bat
             You can also self-build via selfbuild.bat, if that floats your boat.

    Linux: Run linuxbuild.sh (lousy shell script, I know)

== What works ==
    Very simple hello_world builds, and most of my "sample code" stuff in my
    repositories. 

== License ==
    I have no idea what this project is licensed with, Tomasz Stachowiak needs
    to be contacted first. Some code was taken from Tango (by Tomasz), that
    code is BSD-licensed.
