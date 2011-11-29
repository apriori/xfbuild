/+
 +           Copyright Andrej Mitrovic 2011.
 +       Copyright Tomasz Stachowiak 2009 - 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Module;

import xfbuild.Exception;
import xfbuild.GlobalParams;
import xfbuild.Misc;

import std.string : lastIndexOf, splitLines, strip;
import std.algorithm : min;
import std.file;
import std.stdio;
import std.array : replace;
alias strip trim;

// todo: not sure if correct
size_t locatePrior(string source, string match, size_t start = size_t.max)
{
    return lastIndexOf(source[0 .. min(start, $)], match);
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
    Module[] deps;  // only direct deps

    long timeDep;
    long timeModified;

    bool wasCompiled;
    bool needRecompile;

    private string objFile_;

    string objFile()
    {
        if (objFile_)
            return objFile_;

        objFile_ =
            globalParams.objPath
            ~ globalParams.pathSep
            ~ (globalParams.useOQ ? name : replace(name, ".", "-"))
            ~globalParams.objExt;
        
        return objFile;
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
        
        // @BUG@ Workaround: Phobos has issues reading empty files
        if (std.file.getSize(m.path) == 0)
        {
            throw new ModuleException(format("module '%s' is empty", path), __FILE__, __LINE__);
        }
        
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
            throw new ModuleException(format("module '%s' needs module header", path));

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

