module xfbuild.Module;

private 
{
    import xfbuild.GlobalParams;
    import xfbuild.Misc;
}

import std.string : lastIndexOf, splitLines, strip;
import std.algorithm : min;
import std.file;
import std.stdio;
import std.array : replace;
alias strip trim;

// todo: not sure if correct
size_t locatePrior(string source, string match, size_t start = size_t.max)
{
    return lastIndexOf(source[min($, start) .. $], match);
}

class Module
{
    string name;
    string path;

    bool isHeader()
    {
        assert(path.length > 0, name);
        return path[$ - 1] == 'i';
    }

    string lastName()
    {
        //~ locatePrior (source, match, start)          // find prior char
        auto dotPos = locatePrior(name, ".");

        if (dotPos == name.length)
            dotPos = 0;
        else
            ++dotPos;

        return name[dotPos .. $];
    }

    string objFileInFolder()
    {
        auto dotPos = locatePrior(path, ".");
        assert(dotPos != path.length, name);

        return path[0 .. dotPos] ~ globalParams.objExt;
    }

    string[] depNames;
    Module[] deps;              // only direct deps

    long timeDep;
    long timeModified;

    bool wasCompiled;
    bool needRecompile;

    private string objFile_;

    string objFile()
    {
        if (objFile_)
            return objFile_;

        return objFile_ =
            globalParams.objPath
            ~ globalParams.pathSep
            ~ (globalParams.useOQ ? name : replace(name, ".", "-"))
            ~globalParams.objExt;
    }

    bool modified()
    {
        return timeModified > timeDep;
    }

    override string toString()
    {
        return name;
    }

    override hash_t toHash()
    {
        return typeid(typeof(path)).getHash(cast(void*)&path);
    }

    override int opCmp(Object rhs_)
    {
        auto rhs = cast(Module)rhs_;

        if (rhs is this)
            return 0;

        if (this.path > rhs.path)
            return 1;

        if (this.path < rhs.path)
            return -1;

        return 0;
    }

    void addDep(Module mod)
    {
        if (!hasDep(mod))
        {
            deps ~= mod;
        }
    }

    bool hasDep(Module mod)
    {
        foreach (d; deps)
        {
            if (d.name == mod.name)
            {
                return true;
            }
        }

        return false;
    }

    static Module fromFile(string path)
    {
        auto m = new Module;
        m.path         = path;
        m.timeModified = timeLastModified(m.path).stdTime;

        auto file = File(m.path, "r");

        foreach (aLine; file.byLine)
        {
            string line = trim(aLine).idup;

            //if(moduleHeaderRegex.test(line))
            if (auto arr = line.decomposeString(`module`, ` `, null, `;`))
            {
                //m.name = moduleHeaderRegex[1].dup;
                m.name = arr[0];

                if (globalParams.verbose) 
                    writefln("module name for file '%s': %s", path, m.name);

                break;
            }
        }

        if (!m.name)
            throw new Exception(format("module '%s' needs module header", path));

        return m;
    }
}

bool isIgnored(string name)
{
    foreach (m; globalParams.ignore)
    {
        if (name.length >= m.length && name[0 .. m.length] == m)
            return true;
    }

    return false;
}

