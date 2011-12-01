== About xfBuild ==
    This is a port/fork of xfBuild to the D2 programming langauge.
    
    xfBuild was originally made by Tomasz Stachowiak. (http://h3.gd)
    Original Project Homepage: http://bitbucket.org/h3r3tic/xfbuild
    
    xfBuild was ported to D2 by Andrej Mitrovic.
    Port Project Homepage: http://github.com/AndrejMitrovic/xfBuild
    
    ** This is an alpha release, expect bugs. File them if you find them! **

== Building Requirements ==
    - DMD v2.056+ compiler. Download DMD from: http://www.digitalmars.com/d/download.html
      Usage instructions: http://d-programming-language.org/dmd-windows.html
                          http://d-programming-language.org/dmd-linux.html

    xfBuild was tested on XP SP3 and Lubuntu, x86.
    OSX has not yet been tested.
      
== Building xfBuild ==
    Windows: 
        Run build.bat
        Optionally, add to PATH (change this appropriately)
            PATH=%PATH%;c:\xfBuild\

    Linux: 
        Run chmod +x linuxbuild.sh
        Run ./linuxbuild.sh

        Optionally, add to PATH (change this appropriately)
            PATH=$PATH:/home/username/dev/xfBuild/
            export PATH

    Self-Build Note: 
        You might get file overwrite errors if you try to build xfBuild
        with itself. Make sure you're not outputting over the executable
        you're already running.

== Usage Instructions ==
    To output an executable use the +o switch:
        xfBuild +omain.exe main.d (or +omain for linux)
      
    To avoid compiling modules in a path (e.g. Phobos, since DMD links it in implicitly)
    use the +xpath option:
        xfbuild +omain.exe +xpath=D:\DMD\dmd2\src main.d
        
    This can lead to substantially faster builds.
    
    Tip: On Ubuntu use xpath=/usr/include/d/ if xfBuild is having file  
         write errors.
    Tip: If xfbuild is having problems doing incremental compilation,
         try passing the +full switch
    
    Note that if you use the +x (for packages) or +xpath (for paths)
    to avoid compiling modules from a custom library you will typically 
    have to pass the path to the prebuild library. Otherwise you'll
    get linking errors.

== What works ==
    Very simple hello_world builds, and most of my "sample code" stuff in my
    repositories. 

== License ==
    xfBuild is Boost-licensed, acknowledged by the original author Tomasz Stachowiak.
    See accompanying file LICENSE_1_0.txt or copy at
    http://www.boost.org/LICENSE_1_0.txt

== Acknowledgments ==
    Special thanks to Tomasz Stachowiak for creating xfBuild and allowing me
    to license it under the Boost license.
    Thanks to Steven Schveighoffer for creating Dcollections v2.0.

== Contributors ==
    Tomasz Stachowiak
    leod
    Benjamin Saunders
    Daniel Mierswa
    Robert Clipsham
    Vincenzo Ampolo
    digited
    David Nadlinger
    Mathias Baumann
    
    (Note: If your name is missing here, let me know)
    
== Links ==
    D2 Programming Language homepage: http://d-programming-language.org/
    xfBuild Original Homepage: http://bitbucket.org/h3r3tic/xfbuild
    xfBuild Port Homepage: http://github.com/AndrejMitrovic/xfBuild
    WindowsAPI bindings: http://dsource.org/projects/bindings/wiki/WindowsApi
    DCollections: http://www.dsource.org/projects/dcollections
