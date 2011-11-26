/+
 +           Copyright Andrej Mitrovic 2011.
 +       Copyright Tomasz Stachowiak 2009 - 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.GlobalParams;

import std.path;

struct GlobalParams
{
    string compilerName;
    string[] compilerOptions;
    string objPath  = ".objs";
    string depsPath = ".deps";
   
    //string projectFile = "project.xfbuild";
    version (Windows) 
    {
        string objExt = ".obj";
        string exeExt = ".exe";
    }
    else
    {
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
    bool recompileOnUndefinedReference = false;  // todo: still not a RT option
    bool storeStrongSymbols = true;     // TODO
    string pathSep = dirSeparator;
    int maxModulesToCompile = int.max;
    int threadsToUse        = 1;
    bool nolink = false;
    bool removeRspOnFail = true;

    // it sometimes makes OPTLINK not crash... e.g. in Nucled
    bool reverseModuleOrder = false;
    bool moduleByModule     = false;

    bool recursiveModuleScan = false;
    bool useDeps = true;

    version (MultiThreaded) 
    {
        bool manageAffinity = true;
    }
    else
    {
        bool manageAffinity = false;
    }

    size_t linkerAffinityMask = size_t.max;
}

__gshared GlobalParams globalParams;
