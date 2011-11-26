/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Misc;

import xfbuild.BuildException;

import std.algorithm : startsWith;
import std.ascii     : isWhite;
import std.string : format, stripLeft;
alias isWhite isSpace;
alias stripLeft triml;
import std.algorithm : countUntil;
import std.exception;
import std.path;
import std.file;

bool isDirPath(string filePath)
{
    auto last = filePath[$-1];
    return (last == '\\' || last == '/');
}

void verifyMakeFilePath(string filePath, string option)
{
    // std.path is missing isFilePath/isDirPath
    enforceEx!ParseException(!filePath.isDirPath,
                             format("%s option must be a file path, not a directory: `%s`", 
                                     option, 
                                     filePath));
    
    // check invalid chars
    enforceEx!ParseException(filePath.baseName.isValidFilename,
                             format("%s option contains invalid characters: `%s`", 
                                    option, 
                                    filePath));

    auto dirname = filePath.absolutePath.dirName;
    if (!dirname.exists)
    {
        try
        {        
            mkdirRecurse(dirname);
        }
        catch (FileException ex)
        {
            enforceEx!ParseException(0, format("Failed to create output folder for %s option:\n%s", 
                                               option,
                                               ex.toString));
        }
    }
}

unittest
{
    import std.file;
    import std.path;
    import std.range;
    
    auto _tempdir = buildPath(absolutePath("."), "unittest_temp");
    auto workdir = buildPath(_tempdir, "subdir");
    
    mkdirRecurse(_tempdir);
    scope(exit)
    {
        rmdirRecurse(_tempdir);
    }
    
    enum validNames =  
    [   
        `deps`,
        `deps.dep`,
        `out/deps.dep`,
        `../deps`,
        `../deps.dep`,
    ];
    
    enum invalidNames =  
    [   
        `deps/`,
        `out/deps/`,
        `../deps/`,
    ];
    
    foreach (path1, path2; lockstep(validNames, invalidNames))
    {
        auto valid   = buildPath(workdir, path1);
        auto invalid = buildPath(workdir, path2);
        verifyMakeFilePath(valid, "+D");
        assertThrown!ParseException(verifyMakeFilePath(invalid, "") , invalid);
    }
}

size_t locatePattern(string source, string match, size_t start = 0)
{
    // source can be len 0
    start && enforce(start < source.length);
    return countUntil(source[start .. $], match);
}

string[] decomposeString(string str, string[] foo ...)
{
    string[] res;

    foreach (fi, f; foo)
    {
        if (f is null)
        {
            if (fi == foo.length - 1)
            {
                res ~= str;
                str = null;
                break;
            }
            else
            {
                auto delim = foo[fi + 1];
                assert(delim !is null);

                int l = str.locatePattern(delim);
                if (l == -1)
                {
                    return null;  // fail
                }
                
                res ~= str[0..l];
                str = str[l..$];
            }
        }
        else if (" " == f)
        {
            if (str.length > 0 && isSpace(str[0]))
            {
                str = triml(str);
            }
            else
            {
                return null;
            }
        }
        else
        {
            if (str.startsWith(f))
            {
                str = str[f.length..$];
            }
            else
            {
                return null;  // fail
            }
        }
    }

    return str.length > 0 ? null : res;
}

unittest
{
    void test(string[] res, string str, string[] decompose ...)
    {
        assert(res == str.decomposeString(decompose), 
               format("Failed on: %s: got %s instead of %s", 
                      str, 
                      str.decomposeString(decompose), 
                      res));
    }

    test(["Foo.bar.Baz"],                 // result
        `Import::semantic(Foo.bar.Baz)`,  // source
        `Import::semantic(`,              // pattern
        null, 
        `)`);  
    
    test(["Foo.bar.Baz", "lol/wut"],                   // result
        `Import::semantic('Foo.bar.Baz', 'lol/wut')`,  // source
        `Import::semantic('`,                          // pattern
        null, 
        `', '`, 
        null, 
        `')`);  
    
    test(["lolwut"],             // result
        `semantic      lolwut`,  // source
        "semantic",              // pattern
        " ", 
        null);
    
    test([`defend\terrain\Generator.obj`, "Generator"],  // result
        `defend\terrain\Generator.obj(Generator)`,       // source
        cast(string)null,                                // pattern
        "(", 
        null, 
        ")");
    
    test([`.objs\ddl-DDLException.obj`, `ddl-DDLException`],  // result
        `.objs\ddl-DDLException.obj(ddl-DDLException)`,       // source
        cast(string)null,                                     // pattern
        `(`, 
        null, 
        `)`);
}
