/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Compiler;

private 
{
    import xfbuild.GlobalParams;
    import xfbuild.Module;
    import xfbuild.Process;
    import xfbuild.Misc;
    import xfbuild.BuildException;

    import dcollections.HashSet;
    
    import std.parallelism;
    import std.array;
    import std.file;
    import std.stdio;
    
    version (MultiThreaded) 
    {
        import xfbuild.MT;
    }
}

private 
{
    /+Regex	importSemanticStartRegex;
       Regex	importSemanticEndRegex;+/

    //Regex	moduleSemantic1Regex;
    //Regex	verboseRegex;
}

bool isVerboseMsg(string msg) 
{
    return
        msg.startsWith(`parse`)
        || msg.startsWith(`semantic`)
        || msg.startsWith(`function`)
        || msg.startsWith(`import`)
        || msg.startsWith(`library`)
        || msg.startsWith(`code`);
}

// drey todo: replace with shared static this, and for all other modules
shared static this() 
{
    /+importSemanticStartRegex = Regex(`^Import::semantic\('([a-zA-Z0-9._]+)'\)$`);
       importSemanticEndRegex = Regex(`^-Import::semantic\('([a-zA-Z0-9._]+)', '(.+)'\)$`);+/

    //moduleSemantic1Regex = Regex(`^semantic\s+([a-zA-Z0-9._]+)$`);
    //verboseRegex = Regex(`^parse|semantic|function|import|library|code.*`);
}

class CompilerError : BuildException
{
    this(string msg) 
    {
        super(msg);
    }
    
    this(string msg, string file, size_t line, Exception next = null)
    {
        super(msg, file, line, next);
    }
}

// TODO: Cache the escaped paths?
private string unescapePath(string path)
{
    // drey todo: replace with .reserve
    char[] res = (new char[path.length])[0..0];

    for (int i = 0; i < path.length; ++i)
    {
        switch (path[i])
        {
            case '\\':
                ++i;
                goto default;

            // fall through
            default:

                //                writefln("concatenating %s", path[i]).flush;
                res ~= path[i];

                //                writefln("done").flush;
        }
    }

    // todo: remove dup
    return res.idup;
}

string normalizePath(string path)
{
    return replace(path, "\\", "/");
}

void compileAndTrackDeps(
    Module[] compileArray,
    ref Module[string] modules,
    ref Module[] compileMore,
    size_t affinity
    )
{
    Module getModule(string name, string path, bool* newlyEncountered = null)
    {
        Module worker()
        {
            if (auto mp = name in modules)
            {
                return *mp;
            }
            else
            {
                path = normalizePath(path);

                // If there's a corresponding .d file, compile that instead of trying to process a .di
                if (path.length > 3 && path[$ - 3..$] == ".di")
                {
                    if (std.file.exists(path[0..$ - 1]) && std.file.isFile(path[0..$ - 1]))
                    {
                        path = path[0..$ - 1];
                    }
                }

                auto mod = new Module;
                mod.name         = name;
                mod.path         = path;
                mod.timeModified = timeLastModified(mod.path).stdTime;
                assert(modules !is null);
                modules[mod.name] = mod;
                compileMore ~= mod;
                return mod;
            }
        }

        version (MultiThreaded) 
        {
            synchronized (.taskPool) return worker();
        }
        else
        {
            return worker();
        }
    }

    string[] opts;

    if (globalParams.manageHeaders)
        opts ~= "-H";

    string depsFileName;

    if (globalParams.useDeps)
    {
        depsFileName = compileArray[0].name ~ ".moduleDeps";
        opts ~= ["-deps=" ~ depsFileName];
    }

    if (globalParams.moduleByModule)
    {
        foreach (mod; compileArray)
        {
            try
            {
                compile(opts, [mod], 
                        (string line) 
                        {
                            if (!isVerboseMsg(line) && strip(line).length)
                            {
                                // todo: replace to stderr
                                writeln(line);
                                //Stderr(line).newline;
                            }
                        },
                        globalParams.compilerName != "increBuild",     // ==moveObjects?
                        affinity
                        );
            }
            catch (ProcessExecutionException e)
            {
                throw new CompilerError("Error compiling " ~ mod.name, __FILE__, __LINE__, e);
            }
        }
    }
    else
    {
        try
        {
            compile(opts, 
                    compileArray, 
                    (string line) 
                    {
                        if (!isVerboseMsg(line) && strip(line).length)
                        {
                            // todo: replace with stderr
                            writeln(line);
                        }
                    },
                    globalParams.compilerName != "increBuild",     // ==moveObjects?
                    affinity
                    );
        }
        catch (ProcessExecutionException e)
        {
            string mods;

            foreach (i, m; compileArray)
            {
                if (i != 0)
                    mods ~= ",";

                mods ~= m.name;
            }
            
            throw new CompilerError("Error compiling " ~ mods, __FILE__,
                                    __LINE__, e);
        }
    }

    // This must be done after the compilation so if the compiler errors out,
    // then we will keep the old deps instead of clearing them
    foreach (mod; compileArray)
    {
        mod.deps = null;
    }

    if (globalParams.useDeps)
    {
        auto depsFile = File(depsFileName, "r");
        
        scope (exit) 
        {
            depsFile.close();
            std.file.remove(depsFileName);
        }

        //profile!("deps parsing")({
        foreach (aLine; depsFile.byLine)
        {
            auto line = aLine.idup;
            auto arr = line.decomposeString(cast(string)null, ` (`, null, `) : `, null, ` : `, null, ` (`, null, `)`, null);

            if (arr !is null)
            {
                string modName = arr[0];
                string modPath = unescapePath(arr[1]);

                //string prot = arr[2];

                if (!isIgnored(modName))
                {
                    assert(modPath.length > 0);
                    Module m = getModule(modName, modPath);

                    string depName = arr[3];
                    string depPath = unescapePath(arr[4]);

                    if (depName != "object" && !isIgnored(depName))
                    {
                        assert(depPath.length > 0);

                        Module depMod = getModule(depName, depPath);

                        //writefln("Module %s depends on %s", m.name, depMod.name);
                        m.addDep(depMod);
                    }
                }
            }
        }

        //});
    }

    foreach (mod; compileArray)
    {
        mod.timeDep       = mod.timeModified;
        mod.wasCompiled   = true;
        mod.needRecompile = false;

        // remove unwanted headers
        if (!mod.isHeader)
        {
            auto path = mod.path;

            foreach (unwanted; globalParams.noHeaders)
            {
                if (unwanted == mod.name || mod.name is null)
                {
                    if (".d" == path[$ - 2..$])
                    {
                        path = path ~ "i";

                        if (std.file.exists(path) && std.file.isFile(path))
                        {
                            std.file.remove(path);
                        }
                    }
                }
            }
        }
    }
}

void compile(
    string[] extraArgs,
    Module[] compileArray,
    void delegate(string) stdout,
    bool moveObjects,
    size_t affinity,
    )
{
    void execute(string[] args, size_t affinity)
    {
        executeCompilerViaResponseFile(args[0], args[1..$], affinity);
    }

    if (compileArray.length)
    {
        if (!globalParams.useOP && !globalParams.useOQ)
        {
            void doGroup(Module[] group)
            {
                string[] args;

                args ~= globalParams.compilerName;
                args ~= globalParams.compilerOptions;
                args ~= "-c";
                args ~= extraArgs;

                foreach (m; group)
                    args ~= m.path;

                execute(args, affinity);

                if (moveObjects)
                {
                    foreach (m; group)
                    {
                        std.file.rename(m.lastName ~ globalParams.objExt, m.objFile);
                    }
                }
            }

            int[string] lastNames;
            Module[][] passes;

            foreach (m; compileArray)
            {
                string lastName = std.string.toLower(m.lastName);
                int group;

                if (lastName in lastNames)
                    group = ++lastNames[lastName];
                else
                    group = lastNames[lastName] = 0;

                if (passes.length <= group)
                    passes.length = group + 1;

                passes[group] ~= m;
            }

            foreach (pass; passes)
            {
                if (!pass.length)
                    continue;

                doGroup(pass);
            }
        }
        else
        {
            string[] args;
            args ~= globalParams.compilerName;
            args ~= globalParams.compilerOptions;

            if (globalParams.compilerName != "increBuild")
            {
                args ~= "-c";

                if (!globalParams.useOQ)
                {
                    args ~= "-op";
                }
                else
                {
                    args ~= "-oq";
                    args ~= "-od" ~ globalParams.objPath;
                }
            }

            args ~= extraArgs;

            foreach (m; compileArray)
                args ~= m.path;

            auto compiled = compileArray.dup;

            execute(args, affinity);

            if (moveObjects)
            {
                if (!globalParams.useOQ)
                {
                    try
                    {
                        foreach (m; compiled)
                        {
                            try
                            {
                                std.file.rename(m.objFileInFolder, m.objFile);
                            }
                            catch (FileException)
                            {
                                // If the source file being compiled (and hence the
                                // object file as well) and the object directory are
                                // on different volumes, just renaming the file is an
                                // invalid operation on *nix (cross-device link).
                                // Hence, try copy/remove before erroring out.
                                std.file.copy(m.objFileInFolder, m.objFile);
                                std.file.remove(m.objFileInFolder);
                            }
                        }
                    }
                    catch (FileException e)
                    {
                        throw new CompilerError(e.msg);
                    }
                }
            }
        }
    }
}

void compile(ref Module[string] modules /+, ref Module[] moduleStack+/)
{
    /+if (globalParams.verbose) {
            writefln("compile called with: %s", modules.keys);
       }+/

    Module[] compileArray;

    //profile!("finding modules to be compiled")({
    bool[Module][Module] revDeps;

    foreach (mname, m; modules)
    {
        foreach (d; m.deps)
        {
            revDeps[d][m] = true;
        }
    }

    
    auto toCompile = new HashSet!(Module);
    {
        Module[] checkDeps;

        /+foreach (mod; moduleStack) {
                toCompile.add(mod);
                checkDeps ~= mod;
           }+/

        foreach (mname, mod; modules)
        {
            if (mod.needRecompile)
            {
                toCompile.add(mod);
                checkDeps ~= mod;
            }
        }

        while (checkDeps.length > 0)
        {
            auto mod = checkDeps[$ - 1];
            checkDeps = checkDeps[0..$ - 1];

            if (mod !in revDeps)
            {
                //writefln("Module %s is not used by anything", mod.name);
            }
            else
            {
                foreach (rd, _dummy; revDeps[mod])
                {
                    if (!toCompile.contains(rd))
                    {
                        toCompile.add(rd);
                        checkDeps ~= rd;
                    }
                }
            }
        }
    }

    compileArray = array(toCompile);

    if (globalParams.verbose)
    {
        writefln("Modules to be compiled: %s", compileArray);
    }

    //});

    Module[] compileMore;

    bool firstPass = true;

    while (compileArray)
    {
        if (globalParams.reverseModuleOrder)
        {
            compileArray.reverse;
        }

        compileMore = null;

        Module[] compileNow   = compileArray;
        Module[] compileLater = null;

        if (compileNow.length > globalParams.maxModulesToCompile)
        {
            compileNow   = compileArray[0..globalParams.maxModulesToCompile];
            compileLater = compileArray[globalParams.maxModulesToCompile .. $];
        }

        //profile!("compileAndTrackDeps")({
        version (MultiThreaded) 
        {
            int threads = globalParams.threadsToUse;

            // HACK: because affinity is stored in size_t
            // which is also what WinAPI expects;
            // TODO: do this properly one day :P
            if (threads > size_t.sizeof * 8)
            {
                threads = size_t.sizeof * 8;
            }

            Module[][] threadNow   = new Module[][threads];
            Module[][] threadLater = new Module[][threads];

            foreach (th; mtFor(.taskPool, 0, threads))
            {
                auto mods = compileNow[compileNow.length * th / threads .. compileNow.length * (th + 1) / threads];

                if (globalParams.verbose)
                {
                    writefln("Thread %s: compiling %s modules", th, mods.length);
                }

                if (mods.length > 0)
                {
                    compileAndTrackDeps(
                        mods,
                        modules,
                        threadLater[th],
                        getNthAffinityMaskBit(th)
                        );
                }
            }

            foreach (later; threadLater)
            {
                compileLater ~= later;
            }
        }
        else
        {
            compileAndTrackDeps(compileNow, modules, compileLater, size_t.max);
        }

        //});

        //writefln("compileMore: %s", compileMore);

        auto next = compileLater ~ compileMore;

        /*
                In the second pass, the modules from the first one will be compiled anyway
                we'll pass them again to the compiler so it has a chance of better symbol placement
         */
        if (firstPass && next.length > 0)
        {
            compileArray ~= next;
        }
        else
        {
            compileArray = next;
        }

        firstPass = false;
    }
}
