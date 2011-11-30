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
import xfbuild.Exception;
import xfbuild.Process;

import dcollections.HashMap;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.stdio;
import std.file;
import std.path;
import std.string;
import std.c.process;
import std.cpuid : threadsPerCPU;

void printHelpAndQuit(int status)
{
    writeln(
        `xfBuild 0.5.2
http://github.com/AndrejMitrovic/xfbuild

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
    +xpath=PATH     Don't compile any modules within the path
    +full           Perform a full build
    +clean          Perform clean, remove object files
    +redep          Remove the dependency file afterwards
    +v              Print the compilation commands
    +h              Manage headers for faster compilation
    +mod-limit=NUM  Compile max NUM modules at a time
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
    +keeprsp        Don't remove .rsp files upon errors`);

version (MultiThreaded) 
{
writeln(
`
Multithreading options:
    +threads=NUM           Number of theads to use [default: CPU core count]
    +no-affinity           Do NOT manage process affinity (New feature which
                           should prevent DMD hanging on multi-core systems)
    +linker-affinity=MASK  Process affinity mask for the linker
                           (hexadecimal) [default: {:x} (OS-dependent)]`);
}

writeln(
`
Environment Variables:
	XFBUILDFLAGS You can put any option from above into that variable
	               Note: Keep in mind that command line options override
	                     those
	D_COMPILER   The D Compiler to use [default: dmd]
	               Note: XFBUILDFLAGS and command line options override
	                     this`
          );

    debug
        writefln("\nBuilt with %s v%s and Phobos at %s %s",
                        __VENDOR__, __VERSION__, __DATE__, __TIME__);

    exit(status);
}

struct ArgParser
{
    void error(string arg)
    {
        throw new ParseException(format("Unknown argument: +%s", arg));
    }
    
    struct Reg
    {
        string arg;
        void delegate() a;
        void delegate(string) b;
    }

    Reg[] regs;
    
    void bind(string arg, void delegate() a)
    {
        regs ~= Reg(arg, a, null);
    }

    void bind(string arg, void delegate(string) b)
    {
        regs ~= Reg(arg, null, b);
    }

    void parse(string[] args)
    {
argIter:

        foreach (arg; args)
        {
            if (arg.length == 0)
                continue;

            if (arg[0] != '+')
            {
                error(arg);
                continue;
            }

            arg = arg[1..$];

            foreach (reg; regs)
            {
                if (reg.arg.length <= arg.length && reg.arg == arg[0..reg.arg.length])
                {                    
                    try 
                    { 
                        if (reg.a !is null)
                        {
                            reg.a();         
                        }
                        else
                        {
                            reg.b(arg[reg.arg.length..$]);
                        }
                            
                    }
                    catch (Exception e)
                    {
                        enforceEx!ParseException(0, format("Failed to parse option %s.\n\nError: %s", reg.arg, e.toString));
                    }

                    continue argIter;
                }
            }

            error(arg);
        }
    }
}


void determineSystemSpecificOptions()
{
    version (Windows) 
    {
        /* Walter has admitted to OPTLINK having issues with threading */
        globalParams.linkerAffinityMask = getNthAffinityMaskBit(0);
    }
}

int main(string[] allArgs)
{  
    version(Profile)
    {
        auto argsWatch = StopWatch(AutoStart.yes);
        //~ argsWatch.stop();
        //~ writefln("--Profiler-- Argument parsing done in %s msecs.", argsWatch.peek.msecs);
    }
    
    mutex = new Foo;
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

        ArgParser parser;

        auto threadsToUse = max(threadsPerCPU, 1);
        globalParams.threadsToUse = threadsToUse;

        bool quit       = false;
        bool removeObjs = false;
        bool removeDeps = false;

        // support for argument stle without assignment (+oa.exe == +o=a.exe)
        string oldStyleArg(ref string arg)
        {
            arg.munch("=");
            return arg;
        }

        parser.bind("full", 
                    { 
                        removeObjs = true;
                    }
                    );
        parser.bind("clean", 
                    { 
                        removeObjs = true;
                        quit = true;
                    }
                    );
        parser.bind("c", (string arg)    
                    { 
                        globalParams.compilerName = oldStyleArg(arg);
                    }
                    );
        parser.bind("C", (string arg)    
                    { 
                        globalParams.objExt = oldStyleArg(arg);
                    }
                    );  // HACK: should use profiles/configs instead
        parser.bind("O", (string arg)    
                    { 
                        string objPath = oldStyleArg(arg);
                        globalParams.objPath = buildNormalizedPath(objPath);
                    }
                    );                    
        parser.bind("D", (string arg)    
                    {
                        string depsPath = oldStyleArg(arg);
                        verifyMakeFilePath(depsPath, "+D");
                        globalParams.depsPath = depsPath;
                    }
                    );
        parser.bind("o", (string arg)    
                    {
                        // todo: have to remove exe if we're regenerating
                        string outputFile = oldStyleArg(arg);
                        verifyMakeFilePath(outputFile, "+o");
                        globalParams.outputFile = buildNormalizedPath(outputFile);
                    }
                    );
        // major todo: longer arguments with same name must be first in array, otherwise
        // they end up being passed as shorter arguments. We have to implement something
        // better.
        parser.bind("xpath", (string arg)    
                    { 
                        string outPath = oldStyleArg(arg);
                        globalParams.ignorePaths ~= buildNormalizedPath(outPath);
                    }
                    );                        
        parser.bind("x", (string arg)    
                    { 
                        globalParams.ignore ~= oldStyleArg(arg);
                    }
                    );
        parser.bind("modLimit", (string arg)    
                    {
                        globalParams.maxModulesToCompile = to!int(oldStyleArg(arg));
                    }
                    );
        parser.bind("mod-limit=", (string arg)
                    { 
                        globalParams.maxModulesToCompile = to!int(arg);
                    }
                    );
        parser.bind("redep", { removeDeps = true;
                    }
                    );
        parser.bind("v", 
                    { 
                        globalParams.verbose = globalParams.printCommands = true;
                    }
                    );

        //parser.bind("profile", { profiling = true; });
        parser.bind("h", 
                    { 
                        globalParams.manageHeaders = true;
                    }
                    );

        parser.bind("threads", (string arg)    
                    { 
                        globalParams.threadsToUse = to!int(oldStyleArg(arg));
                    }
                    );
        parser.bind("no-affinity", 
                    { 
                        globalParams.manageAffinity = false;
                    }
                    );
        parser.bind("linker-affinity=", (string arg) 
                    { 
                        string x = oldStyleArg(arg); 
                        globalParams.linkerAffinityMask = parse!int(x, 16);
                    }
                    );

        parser.bind("q", 
                    { 
                        globalParams.useOQ = true;
                    }
                    );
        parser.bind("noop", 
                    { 
                        globalParams.useOP = false;
                    }
                    );
        parser.bind("nolink", 
                    { 
                        globalParams.nolink = true;
                    }
                    );
        parser.bind("rmo", 
                    { 
                        globalParams.reverseModuleOrder = true;
                    }
                    );
        parser.bind("mbm", 
                    { 
                        globalParams.moduleByModule = true;
                    }
                    );
        parser.bind("R", 
                    { 
                        globalParams.recursiveModuleScan = true;
                    }
                    );
        parser.bind("nodeps", 
                    { 
                        globalParams.useDeps = false;
                    }
                    );
        parser.bind("keeprsp", 
                    { 
                        globalParams.removeRspOnFail = false;
                    }
                    );

        // remember to parse the XFBUILDFLAGS _before_ args passed in main()
        parser.parse(envArgs);
        parser.parse(args);

        version(Profile)
        {
            argsWatch.stop();
            writefln("--Profiler-- Argument parsing done in %s msecs.", argsWatch.peek.msecs);
        }                    
                    
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

        version(Profile)
        {
            auto scanWatch = StopWatch(AutoStart.yes);
            //~ scanWatch.stop();
            //~ writefln("--Profiler-- Argument parsing done in %s msecs.", scanWatch.peek.msecs);
        }
        
        _ScanForModules(dirsAndModules, mainFiles, globalParams.recursiveModuleScan);
        
        version(Profile)
        {
            scanWatch.stop();
            writefln("--Profiler-- Module scanning done in %s msecs.", scanWatch.peek.msecs);
        }
        
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
            bool doWriteDeps = !removeDeps;
            auto buildTask = BuildTask(doWriteDeps, mainFiles);

            if (!globalParams.objPath.exists)
                mkdir(globalParams.objPath);

            if (removeObjs)
                buildTask.removeObjFiles();

            if (removeDeps)
            {
                try 
                {
                    if (globalParams.depsPath.exists)
                    {
                        std.file.remove(globalParams.depsPath); 
                    }
                }
                catch (Exception exc) 
                {
                    enforceEx!BuildException(0, format("Couldn't remove deps file %s.", globalParams.depsPath));
                }
            }

            if (quit)
                return 0;
            
            enforceEx!ParseException(mainFiles !is null, "At least one Module needs to be specified, see +help.");

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
        writefln("Build failed: %s", e.errorMsg);
        return 1;
    }
}
