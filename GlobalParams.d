module xfbuild.GlobalParams;

// todo: replace
struct ThreadPoolT { }

private 
{
    version (MultiThreaded) 
    {
        //~ import xfbuild.MT : ThreadPoolT;
    }

    //~ import tango.io.model.IFile;
}

import std.path;

struct GlobalParams
{
    string compilerName;
    string[] compilerOptions;
    string objPath  = ".objs";
    string depsPath = ".deps";

    // drey todo: where is the .lib extension?
    // linux might use .a, win uses .lib
    
    //string projectFile = "project.xfbuild";
    version (Windows) 
    {
        string objExt = ".obj";
        string exeExt = ".exe";
    }
    else
    {
        // drey todo: replace with Linux version, OSX
        // and others might be different, do static assert,
        // and replace .o with .a maybe, unless that's only for
        // libraries
        
        string objExt = ".o";
        string exeExt = "";
    }
    string outputFile;
    string workingPath;
    string[] ignore;

    bool manageHeaders = false;
    string[] noHeaders;

    bool verbose;
    bool printCommands;
    int numThreads       = 4;
    bool depCompileUseMT = true;
    bool useOQ = false;
    bool useOP = true;
    bool recompileOnUndefinedReference = false;
    bool storeStrongSymbols = true;     // TODO
    alias dirSeparator pathSep;
    int maxModulesToCompile = int.max;
    int threadsToUse        = 1;
    bool nolink = false;
    bool removeRspOnFail = true;

    // it sometimes makes OPTLINK not crash... e.g. in Nucled
    bool reverseModuleOrder = false;
    bool moduleByModule     = false;

    bool recursiveModuleScan = false;
    bool useDeps = true;

    version (MultiThreaded) {
        bool manageAffinity = true;
    }
    else
    {
        bool manageAffinity = false;
    }

    size_t linkerAffinityMask = size_t.max;
}

__gshared GlobalParams globalParams;

//~ version (MultiThreaded) 
//~ {
    //~ __gshared ThreadPoolT threadPool;
//~ }
