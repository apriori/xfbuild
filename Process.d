/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Process;

private
{
    import xfbuild.GlobalParams;

    version (Windows) 
    {
        import win32.windef;
        import win32.winuser;
        import win32.winbase;
        import win32.winnls;
        
        // note: has to be here as in win32.winbase its protected via version(_WIN32_WINNT_ONLY),
        // maybe it's there for a good reason though..
        extern (Windows) extern BOOL SetProcessAffinityMask(HANDLE, size_t);
        extern (Windows) extern BOOL GetProcessAffinityMask(HANDLE, size_t*, size_t*);
    }    
    
    version (MultiThreaded)
    {
        import core.atomic;
    }
    import std.algorithm;
    import std.concurrency;
    import std.exception;
    import std.process;
    import std.stdio;
    import std.string;
    import std.array;
    import std.utf;
    import std.conv : to;
}

struct SysError
{
    static uint lastCode()
    {
        version (Win32)
            return GetLastError;
        else
        {
            import core.stdc.errno;
            return errno;
        }
    }

    static string lastMsg()
    {
        return lookup(lastCode);
    }

    static string lookup(uint errcode)
    {
        char[] text;

        version (Win32)
        {
            DWORD  i;
            LPWSTR lpMsgBuf;

            i = FormatMessageW(
                FORMAT_MESSAGE_ALLOCATE_BUFFER |
                FORMAT_MESSAGE_FROM_SYSTEM |
                FORMAT_MESSAGE_IGNORE_INSERTS,
                null,
                errcode,
                MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),                         // Default language
                cast(LPWSTR)&lpMsgBuf,
                0,
                null);

            /* Remove \r\n from error string */
            if (i >= 2)
                i -= 2;

            text = new char[i * 3];
            i    = WideCharToMultiByte(CP_UTF8, 0, lpMsgBuf, i,
                                       cast(PCHAR)text.ptr, text.length, null, null);
            text = text [0 .. i];
            LocalFree(cast(HLOCAL)lpMsgBuf);
        }
        else
        {
            import core.stdc.string;
            uint  r;
            char* pemsg;

            pemsg = strerror(errcode);
            r     = strlen(pemsg);

            /* Remove \r\n from error string */
            if (pemsg[r - 1] == '\n')
                r--;

            if (pemsg[r - 1] == '\r')
                r--;

            text = pemsg[0..r].dup;
        }

        // todo: remove dup
        return text.idup;
    }
}

alias reduce!("a ~ ' ' ~ b") flatten;

import std.array;
import std.random;
import std.format;
import std.file;

// modified from std.process.shell 
// (nothrow, saves output)
// note: doesn't pass environment
string shellExecute(string cmd)
{
    // Generate a random filename
    auto a = appender!string();
    foreach (ref e; 0 .. 8)
    {
        formattedWrite(a, "%x", rndGen.front);
        rndGen.popFront;
    }
    auto filename = a.data;
    scope(exit) if (exists(filename)) remove(filename);
    auto result = system(cmd ~ "> " ~ filename);
    return readText(filename);    
}

struct Process
{
    string[] args;
    
    this(bool copyEnv, string[] args)
    {
        // todo: can't find anything in phobos to pass environment
        // and return stdout/stderr output, OR just execute process
        // and redirect stdout/stderr. execvpe isn't useful since 
        // I can't redirect via ' > ' in its call.
        this.args = args;
    }
    
    string execute()
    {
        auto cmd = flatten(args);
        return shellExecute(cmd);
    }

    // todo
    string toString()
    {
        return "";
    }

    // todo
    struct Result
    {
        int status;
    }

    // todo
    Result wait()
    {
        return Result(0);
    }

    // todo
    ~this()
    {
    }
}

class ProcessExecutionException : Exception
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

void checkProcessFail(Process process)
{
    auto result = process.wait();

    if (result.status != 0)
    {
        auto name = process.toString();

        if (name.length > 255)
            name = name[0 .. 255] ~ " [...]";

        throw new ProcessExecutionException(`"` ~ name ~ `" returned ` ~ to!string(result.status), __FILE__, __LINE__);
    }
}

string execute(Process process)
{
    return process.execute();

    // todo
    //~ if (globalParams.printCommands)
    //~ {
        //~ writeln(process);
    //~ }
}

void executeAndCheckFail(string[] cmd, size_t affinity)
{
    void runNoAffinity()
    {
        string sys = cmd.join(" ");
        int ret    = system(sys);

        if (ret != 0)
        {
            throw new ProcessExecutionException(`"` ~ sys ~ `" returned ` ~ to!string(ret), __FILE__, __LINE__);
        }
    }

    // todo: affinity
    runNoAffinity();
}

__gshared int value;

void executeCompilerViaResponseFile(string compiler, string[] args, size_t affinity)
{
    version (MultiThreaded)
    {
        atomicOp!"+="(value, 1);
    }
    else
    {
        value += 1;
    }
    
    string rspFile = format("xfbuild.%s.rsp", value);    
    string rspData = args.join("\n");

    /+if (globalParams.verbose) {
            writefln("running the compiler with:\n%s", rspData);
       }+/
    auto file = File(rspFile, "w");
    file.write(rspData);

    scope (failure)
    {
        if (globalParams.removeRspOnFail)
        {
            std.file.remove(rspFile);
        }
    }

    scope (success)
    {
        std.file.remove(rspFile);
    }

    file.close();
    executeAndCheckFail([compiler, "@" ~ rspFile], affinity);
}

size_t getNthAffinityMaskBit(size_t n)
{
    version (Windows)
    {
        /*
         * This basically asks the system for the affinity
         * mask and uses the N-th set bit in it, where
         * N == thread id % number of bits set in the mask.
         *
         * Could be rewritten with intrinsics, but only
         * DMD seems to have these.
         */

        size_t sysAffinity, thisAffinity;

        if (!GetProcessAffinityMask(
                GetCurrentProcess(),
                &thisAffinity,
                &sysAffinity
                ) || 0 == sysAffinity)
        {
            throw new Exception("GetProcessAffinityMask failed");
        }

        size_t i = n;
        size_t affinityMask = 1;

        while (i-- != 0)
        {
            do
            {
                affinityMask <<= 1;

                if (0 == affinityMask)
                {
                    affinityMask = 1;
                }
            }
            while (0 == (affinityMask & thisAffinity));
        }

        affinityMask &= thisAffinity;
        assert(affinityMask != 0);
    }
    else
    {
        // TODO

        assert(n < size_t.sizeof * 8);
        size_t affinityMask = 1;
        affinityMask <<= n;
    }

    return affinityMask;
}
