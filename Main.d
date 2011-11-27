/+
 +           Copyright Andrej Mitrovic 2011.
 +       Copyright Tomasz Stachowiak 2009 - 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Main;

import xfbuild.MT;
import xfbuild.BuildTask;
import xfbuild.Misc;
import xfbuild.Compiler : CompilerError;
import xfbuild.GlobalParams;
import xfbuild.BuildException;
import xfbuild.Process;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.file;
import std.path;
import std.c.process;
import std.process;
import std.parallelism : totalCPUs;
import std.cpuid : threadsPerCPU;

void printHelpAndQuit(int status)
{
    writeln(
        `xfBuild 0.5.0
http://bitbucket.org/h3r3tic/xfbuild/

Usage:
    xfbuild [+help]
    xfbuild [ROOT | OPTION | COMPILER OPTION]...

    Track dependencies and their changes of one or more modules, compile them
    with COMPILER OPTION(s) and link all objects into OUTPUT [see OPTION(s)].

ROOT:
    String ended with either ".d" or "/" indicating a module
    or a directory of modules to be compiled, respectively.

    OPTION(s) are prefixed by "+".
    COMPILER OPTION(s) are anything that is not OPTION(s) or ROOT(s).

Recognized OPTION(s):
    +x=PACKAGE      Don't compile any modules within the package
    +full           Perform a full build
    +clean          Perform clean, remove object files
    +redep          Remove the dependency file afterwards
    +v              Print the compilation commands
    +h              Manage headers for faster compilation
`

        //    +profile     Dump profiling info at the end
        `    +mod-limit=NUM  Compile max NUM modules at a time
    +D=DEPS         Put the resulting dependencies into DEPS [default: .deps]
    +O=OBJS         Put compiled objects into OBJS [default: .objs]
    +q              Use -oq when compiling (only supported by ldc)
    +noop           Don't use -op when compiling
    +nolink         Don't link
    +o=OUTPUT       Link objects into the resulting binary OUTPUT
    +c=COMPILER     Use the D Compiler COMPILER [default: dmd]
    +C=EXT          Extension of the compiler-generated object files
                    [default: .obj on Windows, .o otherwise]
    +rmo            Reverse Module Order
                    (when compiling - might uncrash OPTLINK)
    +mbm            Module By Module, compiles one module at a time
                    (useful to debug some compiler bugs)
    +R              Recursively scan directories for modules
    +nodeps         Don't use dependencies' file
    +keeprsp        Don't remove .rsp files upon errors`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        );
    version (MultiThreaded) 
    {
        writeln(`

Multithreading options:
    +threads=NUM           Number of theads to use [default: CPU core count]
    +no-affinity           Do NOT manage process affinity (New feature which
                           should prevent DMD hanging on multi-core systems)
    +linker-affinity=MASK  Process affinity mask for the linker
                           (hexadecimal) [default: {:x} (OS-dependent)]`,
                        globalParams.linkerAffinityMask
                        );
    }

    writeln(`
	
Environment Variables:
	XFBUILDFLAGS You can put any option from above into that variable
	               Note: Keep in mind that command line options override
	                     those
	D_COMPILER   The D Compiler to use [default: dmd]
	               Note: XFBUILDFLAGS and command line options override
	                     this
`
          );

    debug
        writefln("\nBuilt with %s v%s and Phobos at %s %s\n",
                        __VENDOR__, __VERSION__, __DATE__, __TIME__);

    exit(status);
}

struct ArgParser
{
    void delegate(string) err;
    
    struct Reg
    {
        string t;
        void delegate() a;
        void delegate(string) b;
    }

    Reg[] reg;
    void bind(string t, void delegate() a)
    {
        reg ~= Reg(t, a, null);
    }

    void bind(string t, void delegate(string) b)
    {
        reg ~= Reg(t, null, b);
    }

    void parse(string[] args)
    {
argIter:

        foreach (arg; args)
        {
            if (0 == arg.length)
                continue;

            if (arg[0] != '+')
            {
                err(arg);
                continue;
            }

            arg = arg[1..$];

            foreach (r; reg)
            {
                if (r.t.length <= arg.length && r.t == arg[0..r.t.length])
                {
                    if (r.a !is null)
                        r.a();
                    else
                        r.b(arg[r.t.length..$]);

                    continue argIter;
                }
            }

            err(arg);
        }
    }
}


void determineSystemSpecificOptions()
{
    version (Windows) {
        /* Walter has admitted to OPTLINK having issues with threading */
        globalParams.linkerAffinityMask = getNthAffinityMaskBit(0);
    }
}

int main(string[] allArgs)
{
    determineSystemSpecificOptions();

    string[] envArgs;

    if (std.process.environment.get("XFBUILDFLAGS"))
    {
        foreach (flag; split(std.process.environment.get("XFBUILDFLAGS"), " "))
        {
            if (0 != flag.length)
            {
                envArgs ~= flag;
            }
        }
    }

    globalParams.compilerName = std.process.environment.get("D_COMPILER", "dmd");

    if (0 == envArgs.length && 1 == allArgs.length)
    {
        // wrong invocation, return failure
        printHelpAndQuit(1);
    }

    if (2 == allArgs.length && "+help" == allArgs[1])
    {
        // standard help screen
        printHelpAndQuit(0);
    }

    bool profiling = false;

    string[] args;
    string[] mainFiles;

    try
    {
        //profile!("main")({
        string[] dirsAndModules;

        foreach (arg; allArgs[1..$])
        {
            if (0 == arg.length)
                continue;

            if ('-' == arg[0])
            {
                globalParams.compilerOptions ~= arg;
            }
            else if ('+' == arg[0])
            {
                args ~= arg;
            }
            else
            {
                if ((arg == "." || arg == "./" || arg == "/" || arg.length > 2)
                    && (arg[$ - 2..$] == ".d" || arg[$ - 1] == '/'))
                {
                    dirsAndModules ~= arg;
                }
                else
                {
                    globalParams.compilerOptions ~= arg;
                }
            }
        }

        auto parser = ArgParser((string arg) {
                                    throw new Exception("unknown argument: " ~ arg);
                                }
                                );


        auto threadsToUse = max(threadsPerCPU, 1);
        globalParams.threadsToUse = threadsToUse;

        bool quit       = false;
        bool removeObjs = false;
        bool removeDeps = false;

        // support for the olde arg style where they didn't have to be
        // preceded with an equal sign
        string olde(string arg)
        {
            if (arg.length > 0 && '=' == arg[0])
            {
                return arg[1..$];
            }
            else
            {
                return arg;
            }
        }

        parser.bind("full", { removeObjs = true;
                    }
                    );
        parser.bind("clean", { removeObjs = true;
                               quit = true;
                    }
                    );
        parser.bind("c", (string arg)    { globalParams.compilerName = olde(arg);
                    }
                    );
        parser.bind("C", (string arg)    { globalParams.objExt = olde(arg);
                    }
                    );                                                                                                  // HACK: should use profiles/configs instead
        parser.bind("O", (string arg)    { globalParams.objPath = olde(arg);
                    }
                    );                    
        parser.bind("D", (string arg)    
                    {
                        string depsPath = olde(arg);
                        verifyMakeFilePath(depsPath, "+D");
                        globalParams.depsPath = depsPath;
                    }
                    );
        parser.bind("o", (string arg)    
                    { 
                        // todo: have to remove exe if we're regenerating
                        string outputFile = olde(arg);
                        verifyMakeFilePath(outputFile, "+o");
                        globalParams.outputFile = outputFile;
                    }
                    );
        parser.bind("x", (string arg)    { globalParams.ignore ~= olde(arg);
                    }
                    );
        parser.bind("modLimit", (string arg)    { globalParams.maxModulesToCompile = to!int(olde(arg));
                    }
                    );
        parser.bind("mod-limit=", (string arg){ globalParams.maxModulesToCompile = to!int(arg);
                    }
                    );
        parser.bind("redep", { removeDeps = true;
                    }
                    );
        parser.bind("v", { globalParams.verbose = globalParams.printCommands = true;
                    }
                    );

        //parser.bind("profile",			        { profiling = true; });
        parser.bind("h", { globalParams.manageHeaders = true;
                    }
                    );

        parser.bind("threads", (string arg)    { globalParams.threadsToUse = to!int(olde(arg));
                    }
                    );
        parser.bind("no-affinity", { globalParams.manageAffinity = false;
                    }
                    );
        parser.bind("linker-affinity=", (string arg){ char[] x = olde(arg).dup; globalParams.linkerAffinityMask = parse!int(x, 16);
                    }
                    );

        parser.bind("q", { globalParams.useOQ = true;
                    }
                    );
        parser.bind("noop", { globalParams.useOP = false;
                    }
                    );
        parser.bind("nolink", { globalParams.nolink = true;
                    }
                    );
        parser.bind("rmo", { globalParams.reverseModuleOrder = true;
                    }
                    );
        parser.bind("mbm", { globalParams.moduleByModule = true;
                    }
                    );
        parser.bind("R", { globalParams.recursiveModuleScan = true;
                    }
                    );
        parser.bind("nodeps", { globalParams.useDeps = false;
                    }
                    );
        parser.bind("keeprsp", { globalParams.removeRspOnFail = false;
                    }
                    );

        // remember to parse the XFBUILDFLAGS _before_ args passed in main()
        parser.parse(envArgs);
        parser.parse(args);

        //------------------------------------------------------------
        void _ScanForModules(string[] paths, ref string[] modules, bool recursive = false, bool justCheckAFolder = false)
        {
            foreach (child; paths)
            {
                if (child.exists())
                {
                    if (child.isFile)
                    {
                        if (child.extension == ".d")
                        {
                            // major todo: this used to be .toString
                            modules ~= child;
                        }
                    }
                }
                else
                {
                    throw new Exception("File not found: " ~ child);
                }
            }
        }

        //-----------------------------------------------------------

        _ScanForModules(dirsAndModules, mainFiles, globalParams.recursiveModuleScan);

        if ("increBuild" == globalParams.compilerName)
        {
            globalParams.useOP  = true;
            globalParams.nolink = true;
        }

        /+{
                if (std.file.exists(globalParams.projectFile) && Path.isFile(globalParams.projectFile)) {
                        scope json = new Json!(char);
                        auto jobj = json.parse('{' ~ cast(string)File.get(globalParams.projectFile) ~ '}').toObject.hashmap();
                        if (auto noHeaders = "noHeaders" in jobj) {
                                auto arr = (*noHeaders).toArray();
                                foreach (nh; arr) {
                                        auto modName = nh.toString();
                                        globalParams.noHeaders ~= modName;
                                }
                        }
                }
           }+/
        
        {
            
            auto buildTask = BuildTask(!removeDeps, mainFiles);

            if (!std.file.exists(globalParams.objPath))
                mkdir(globalParams.objPath);

            if (removeObjs)
                buildTask.removeObjFiles();

            if (removeDeps)
            {
                try 
                {
                    if (std.file.exists(globalParams.depsPath))
                    {
                        std.file.remove(globalParams.depsPath); 
                    }
                }
                catch (Exception exc) 
                { 
                    writeln("Couldn't remove deps file."); 
                }
            }

            if (quit)
                return 0;

            
            if (mainFiles is null)
                throw new Exception("At least one MODULE needs to be specified, see +help");

            buildTask.execute();
        }

        //});

        /+if (profiling) {
                scope formatter = new ProfilingDataFormatter;
                foreach (row, col, node; formatter) {
                        char[256] spaces = ' ';
                        int numSpaces = node.bottleneck ? col-1 : col;
                        if (numSpaces < 0) numSpaces = 0;
                        writefln("%s%s%s", node.bottleneck ? "*" : "", spaces[0..numSpaces], node.text);
                }
           }+/

        return 0;
    }
    catch (BuildException e)
    {
        writefln("Build failed: %s", e);
        return 1;
    }
}
