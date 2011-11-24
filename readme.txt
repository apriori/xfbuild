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
    
    - DCollections 2.0 (included). Obtainable from:
        http://www.dsource.org/projects/dcollections

    Tested on XP SP3 and Lubuntu, x86.
      
== Building xfBuild ==
    Windows: 
        Run build.bat
        Alternatively use selfbuild.bat for self builds.
        
        Optionally, add to PATH (change this appropriately)
            PATH=%PATH%;c:\xfBuild\

    Linux: 
        Run chmod a-w+x linuxbuild.sh
        Run ./linuxbuild.sh (lousy shell script, I know)

        Optionally, add to PATH (change this appropriately)
            PATH=$PATH:/home/username/dev/xfBuild/
            export PATH

== Using xfBuild ==
    Run xfBuild to see all the options. 
    To get an executable use the +o switch:
      
      xfBuild main.d +omain.exe

== What works ==
    Very simple hello_world builds, and most of my "sample code" stuff in my
    repositories. 

== License ==
    I have no idea what this project is licensed with, Tomasz Stachowiak needs
    to be contacted first. Some code was taken from Tango (by Tomasz), that
    code is BSD-licensed.

== Acknowledgments ==
    Special thanks to Tomasz Stachowiak for making xfBuild.

== Links ==
    D2 Programming Language homepage: http://d-programming-language.org/
    xfBuild Original Homepage: http://bitbucket.org/h3r3tic/xfbuild
    xfBuild Port Homepage: http://github.com/AndrejMitrovic/xfBuild
    WindowsAPI bindings: http://dsource.org/projects/bindings/wiki/WindowsApi
    DCollections: http://www.dsource.org/projects/dcollections
