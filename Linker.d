/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Linker;

import xfbuild.GlobalParams;
import xfbuild.Module;
import xfbuild.Process;
import xfbuild.Misc;

import std.algorithm;
import std.ascii : isAlpha;
import std.array;
import std.exception;
import std.stdio;

/+ {
        Regex linkerFileRegex;
   }

   shared static this() {
        //defend\terrain\Generator.obj(Generator)
        //linkerFileRegex = Regex(`([a-zA-Z0-9.:_\-\\/]+)\(.*\)`);
   }+/

bool isValidObjFileName(string f)
{
    foreach (c; f)
    {
        if (!isAlpha(c) && !(`.:_-\/`.canFind(c)))
        {
            return false;
        }
    }

    return true;
}

bool link(ref Module[string] modules, string[] mainFiles = null)
{
    bool retryCompile;

    string[] args;
    args ~= globalParams.compilerName;
    args ~= globalParams.compilerOptions;

    foreach (k; mainFiles)
    {
        foreach (m; modules)
        {
            if (m.path == k)
            {
                if (!m.isHeader)
                    args ~= m.objFile;

                break;
            }
        }
    }

    foreach (k, m; modules)
    {
        if (m.isHeader || canFind(mainFiles, m.path))
            continue;

        args ~= m.objFile;
    }

    args ~= "-of" ~ globalParams.outputFile;

    if (globalParams.recompileOnUndefinedReference)
    {
        executeCompilerViaResponseFile(
            args[0],
            args[1..$],
            globalParams.linkerAffinityMask
            );
    }
    else
    {
        auto process = Process(true, args);
        auto output = execute(process);

        string currentFile   = null;
        Module currentModule = null;

        foreach (line; output.splitLines)
        {
            line = strip(line);

            if (line.length > 0)
            {
                writefln("linker: '%s'", line);
            }

            try
            {
                auto arr = line.decomposeString(cast(string)null, "(", null, ")");

                //if(linkerFileRegex.test(line))
                if (arr && isValidObjFileName(arr[1]))
                {
                    //currentFile = linkerFileRegex[1];
                    currentFile = arr[1];

                    foreach (m; modules)
                        if (m.objFile == currentFile)
                            currentModule = m;

                    if (!currentModule && globalParams.verbose)
                    {
                        writefln("%s doesn't belong to any known module", currentFile);
                        continue;
                    }

                    if (globalParams.verbose)
                        writefln("linker error in file %s (module %s)", currentFile, currentModule);
                }
                else if (/*undefinedReferenceRegex.test(line)*/ line.startsWith("Error 42:") && globalParams.recompileOnUndefinedReference)
                {
                    if (globalParams.verbose)
                    {
                        if (!currentFile || !currentModule)
                        {
                            writeln("no file..?");

                            //continue; // as i currently recompile every file anyway...
                        }

                        /*writefln("undefined reference to %s, will try to recompile %s", undefinedReferenceRegex[1], currentModule);

                           currentModule.needRecompile = true;
                           retryCompile = true;*/

                        writeln("undefined reference, will try the full recompile");

                        foreach (m; modules)
                            m.needRecompile = true;

                        retryCompile = true;

                        break;
                    }
                }
            }
            catch (Exception e)
            {
                if (currentFile && currentModule)
                {
                    writefln("%s", e);
                    writefln("utf8 exception caught, assuming linker error in file %s", currentModule);

                    // orly!
                    foreach (m; modules)
                        m.needRecompile = true;

                    retryCompile = true;

                    break;
                }
                else
                {
                    throw e;
                }
            }
        }

        try
        {
            // todo: replace with a system call? find one which returns 0,
            // it's probably synchronous
            checkProcessFail(process);
        }
        catch (Exception e)
        {
            version (Windows) 
            {
                // I don't know if Windows is affected too?
            }
            else
            {
                // DMD somehow puts some linker errors onto stdout
                //~ Stderr.copy(process.stdout).flush;
            }

            if (retryCompile && globalParams.verbose)
                writeln("ignoring linker error, will try to recompile");
            else if (!retryCompile)
                throw e;                 // rethrow exception since we're not going to retry what we did

        }
    }

    globalParams.recompileOnUndefinedReference = false;     // avoid infinite loop

    return retryCompile;
}
