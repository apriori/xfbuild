/+
 +           Copyright Andrej Mitrovic 2011.
 +       Copyright Tomasz Stachowiak 2009 - 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.BuildTask;

import xfbuild.GlobalParams;
import xfbuild.Module;
import xfbuild.Compiler;
import xfbuild.Linker;
import xfbuild.Misc;

import std.algorithm;
import std.file;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;
import std.path;

struct BuildTask
{
    Module[string]  modules;
    string[] mainFiles;
    bool doWriteDeps = true;

    //Module[]	moduleStack;

    this(bool doWriteDeps, string[] mainFiles ...)
    {
        this.doWriteDeps = doWriteDeps;
        this.mainFiles   = mainFiles;

        //profile!("BuildTask.readDeps")({

        readDeps();

        //});
    }

    ~this()
    {
        //profile!("BuildTask.writeDeps")({
        if (this.doWriteDeps)
        {
            writeDeps();
        }

        //});
    }

    void execute()
    {
        //profile!("BuildTask.execute")({
        if (globalParams.nolink)
            compile();
        else
            do
                compile();
            while (link());

        //});
    }

    void compile()
    {
        version (Profile)
        {
            auto sw = StopWatch(AutoStart.yes);
            scope (exit)
            {
                sw.stop();
                writefln("--Profiler-- Compiling done in %s msecs.", sw.peek.msecs);
            }
        }
        
        //profile!("BuildTask.compile")({
        //if (moduleStack.length > 0) {
        .compile(modules);

        //}
        //});
    }

    bool link()
    {
        version (Profile)
        {
            auto sw = StopWatch(AutoStart.yes);
            scope (exit)
            {
                sw.stop();
                writefln("--Profiler-- Linking done in %s msecs.", sw.peek.msecs);
            }
        }              
        
        if (globalParams.outputFile is null)
        {
            return false;
        }

        //return profile!("BuildTask.link")({
        return .link(modules, mainFiles);

        //});
    }

    // todo: refactor this
    private void readDeps()
    {
        version (Profile)
        {
            auto sw = StopWatch(AutoStart.yes);
            scope (exit)
            {
                sw.stop();
                writefln("--Profiler-- Reading deps done in %s msecs.", sw.peek.msecs);
            }
        }
        
        if (globalParams.useDeps && globalParams.depsPath.exists)
        {
            auto depsPath = globalParams.depsPath;
            
            if (depsPath.exists && std.file.getSize(depsPath) > 0)
            {
                auto depsFile = File(depsPath, "r");
                scope(exit)
                {
                    // @BUG@ 7022 workaround
                    depsFile.close();
                }                
                
                foreach (aLine; depsFile.byLine)
                {
                    string line = strip(aLine).idup;

                    if (!line.length)
                        continue;

                    /*auto firstSpace = TextUtil.locate(line, ' ');
                       auto thirdSpace = TextUtil.locatePrior(line, ' ');
                       auto secondSpace = TextUtil.locatePrior(line, ' ', thirdSpace);

                       auto name = line[0 .. firstSpace];
                       auto path = line[firstSpace + 1 .. secondSpace];
                       auto time = to!long(line[secondSpace + 1 .. thirdSpace]);
                       auto deps = line[thirdSpace + 1 .. $];*/

                    /+if(!depLineRegex.test(line))
                            throw new Exception("broken .deps file (line: " ~ line ~ ")");

                       auto name = depLineRegex[1];
                       auto path = depLineRegex[2];
                       auto time = to!long(depLineRegex[3]);
                       auto deps = depLineRegex[4];+/

                    auto arr = line.decomposeString(cast(string)null, ` `, null, ` `, null, ` `, null);

                    if (arr is null)
                    {
                        arr = line.decomposeString(cast(string)null, ` `, null, ` `, null);
                    }

                    if (arr is null)
                        throw new Exception("broken .deps file (line: " ~ line ~ ")");

                    auto name = arr[0];
                    auto path = arr[1];
                    long time;

                    try
                    {
                        time = to!long(arr[2]);
                    }
                    catch (Exception e)
                    {
                        throw new Exception("broken .deps file (line: " ~ line ~ ")");
                    }

                    auto deps = arr.length > 3 ? arr[3] : null;

                    if (isIgnored(name))
                    {
                        if (globalParams.verbose)
                            writeln(name ~ " is ignored");
                        continue;
                    }
                    
                    auto realPath = dirName(buildNormalizedPath(path));
                    if (isPathIgnored(realPath))
                    {
                        if (globalParams.verbose)
                            writeln(path ~ " is ignored");
                        continue;
                    }

                    //Stdout(time, deps).newline;

                    if (!path.exists)
                        continue;

                    auto m = new Module;
                    m.name         = name;
                    m.path         = path;
                    m.timeDep      = time;
                    m.timeModified = timeLastModified(path).stdTime;

                    if (m.modified && !m.isHeader)
                    {
                        if (globalParams.verbose)
                        {
                            //~ writefln("%s was modified", m.name);
                        }

                        m.needRecompile = true;

                        //moduleStack ~= m;
                    }
                    else if (globalParams.compilerName != "increBuild")
                    {
                        if (!m.objFile.exists)
                        {
                            if (globalParams.verbose)
                                writefln("%s's obj file was removed", m.name);

                            m.needRecompile = true;

                            //moduleStack ~= m;
                        }
                    }

                    if (deps)
                    {
                        foreach (dep; splitter(deps, ","))
                        {
                            if (!dep.length)
                                continue;                          
                            
                            if (isIgnored(dep))
                            {
                                if (globalParams.verbose)
                                    writeln(dep ~ " is ignored");

                                continue;
                            }

                            m.depNames ~= dep;
                        }
                    }

                    modules[name] = m;
                }
            }

            foreach (m; modules)
            {
                foreach (d; m.depNames)
                {
                    if (auto x = (d in modules))
                    {
                        m.addDep(*x);
                    }
                }
            }
        }

        foreach (mainFile; mainFiles)
        {
            auto m = Module.fromFile(mainFile);

            if (m.name !in modules)
            {
                modules[m.name] = m;

                //moduleStack ~= m;
                m.needRecompile = true;
            }
        }
    }

    private void writeDeps()
    {
        version (Profile)
        {
            auto sw = StopWatch(AutoStart.yes);
            scope (exit)
            {
                sw.stop();
                writefln("--Profiler-- Writing deps done in %s msecs.", sw.peek.msecs);
            }
        }      
        
        auto depsFile = File(globalParams.depsPath, "w");
        scope(exit)
        {
            // @BUG@ 7022 workaround
            depsFile.close();
        }

        foreach (m; modules)
        {
            if (m.path.length > 0)
            {
                depsFile.write(m.name);
                depsFile.write(" ");
                depsFile.write(m.path);
                depsFile.write(" ");
                depsFile.write(to!string(m.timeDep));
                depsFile.write(" ");

                foreach (d; m.deps)
                {
                    depsFile.write(d.name);
                    depsFile.write(",");
                }

                depsFile.writeln;
            }
        }
    }

    void removeObjFiles()
    {
        /*if(std.file.exists(objPath))
           {
                foreach(info; Path.children(objPath))
                {
                        if(!info.folder && Path.parse(info.name).ext == objExt[1 .. $])
                                std.file.remove(info.path ~ info.name);
                }
           }*/

        foreach (m; modules)
        {
            if (m.objFile.exists)
            {
                std.file.remove(m.objFile);
                m.needRecompile = true;
            }
        }
    }
}
