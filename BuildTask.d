module xfbuild.BuildTask;

private 
{
    import xfbuild.GlobalParams;
    import xfbuild.Module;
    import xfbuild.Compiler;
    import xfbuild.Linker;
    import xfbuild.Misc;

    import std.algorithm;
    import std.file;
    import std.conv;
    import std.stdio;
    import std.string;
}

private 
{
    // todo: doesn't seem to be used
    //~ Regex depLineRegex;
}

shared static this() 
{
    //defend.sim.obj.Building defend\sim\obj\Building.d 633668860572812500 defend.Main,defend.sim.Import,defend.sim.obj.House,defend.sim.obj.Citizen,defend.sim.civ.Test,
    //depLineRegex = Regex(`([a-zA-Z0-9._]+)\ ([a-zA-Z0-9.:_\-\\/]+)\ ([0-9]+)\ (.*)`);
}

// todo: might need to be refcounted, originally a scope class
struct BuildTask
{
    Module[string]  modules;
    string[] mainFiles;
    bool doWriteDeps = true;

    //Module[]	moduleStack;

    this( bool doWriteDeps, string[] mainFiles ...)
    {
        this.doWriteDeps = doWriteDeps;
        this.mainFiles   = mainFiles;

        //profile!("BuildTask.readDeps")({
        
        readDeps();
        

        //});
    }

    ~this( )
    {
        //profile!("BuildTask.writeDeps")({
        if (this.doWriteDeps)
            writeDeps();

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
        //profile!("BuildTask.compile")({
        //if (moduleStack.length > 0) {
        .compile(modules);

        //}
        //});
    }

    bool link()
    {
        if (globalParams.outputFile is null)
        {
            return false;
        }

        //return profile!("BuildTask.link")({
        return .link(modules, mainFiles);

        //});
    }

    private void readDeps()
    {
        
        if (globalParams.useDeps && std.file.exists(globalParams.depsPath))
        {
            
            auto file = File(globalParams.depsPath, "r");
            
            foreach (aLine; file.byLine)
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

                //Stdout(time, deps).newline;

                if (!std.file.exists(path))
                    continue;

                auto m = new Module;
                m.name         = name;
                m.path         = path;
                m.timeDep      = time;
                m.timeModified = timeLastModified(path).stdTime;

                if (m.modified && !m.isHeader)
                {
                    if (globalParams.verbose)
                        writefln("%s was modified", m.name);

                    m.needRecompile = true;

                    //moduleStack ~= m;
                }
                else if (globalParams.compilerName != "increBuild")
                {
                    if (!std.file.exists(m.objFile))
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

            foreach (m; modules)
            {
                foreach (d; m.depNames)
                {
                    // drey: simplified
                    if (auto x = (d in modules))
                    {
                        m.addDep(*x);
                    }
                }
            }
        }

        
        foreach (mainFile; mainFiles)
        {
            
            
            // fail:
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
        auto file = File(globalParams.depsPath, "w");
        
        foreach (m; modules)
        {
            if (m.path.length > 0)
            {
                file.write(m.name);
                file.write(" ");
                file.write(m.path);
                file.write(" ");
                file.write(to!string(m.timeDep));
                file.write(" ");

                foreach (d; m.deps)
                {
                    file.write(d.name);
                    file.write(",");
                }

                file.write("\n");
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
            if (std.file.exists(m.objFile))
            {
                std.file.remove(m.objFile);
                m.needRecompile = true;
            }
        }
    }
}
