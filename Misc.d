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

// complicated beast..
void verifyMakeFilePath(string filePath, string option, string name)
{
    // syntactic verification
    auto last = filePath[$-1];
    if (last == '\\' || last == '/')
    {
        throw new ParseException(format("%s must be a file path, not a directory: \"+%s=%s\"", 
                                        name, 
                                        option, 
                                        filePath),
                                 __FILE__, __LINE__);
    }
    
    if (!isValidFilename(filePath.baseName))
    {
        throw new ParseException(format("%s file path contains invalid characters: \"+%s=%s\"", 
                                        name, 
                                        option, 
                                        filePath),
                                 __FILE__, __LINE__);
    }
    
    // existing dir/file scenario
    if (filePath.exists)
    {
        enforce(!filePath.isDir, 
                new ParseException(format("%s file path is an existing directory: \"+%s=%s\"", 
                                          name, 
                                          option, 
                                          filePath), 
                                   __FILE__, __LINE__));
        
        // will overwrite file
        return;  
    }
    else
    {
        try
        {
            auto dirname = filePath.absolutePath.dirName;
            if (!dirname.exists)
            {
                mkdirRecurse(dirname);
            }
        }
        catch (FileException ex)
        {
            throw new ParseException(format("Failed to create folder for the %s file:\n%s", 
                                            name, 
                                            ex.toString),
                                     __FILE__, __LINE__);
        }
    }
}

size_t locatePattern(string source, string match, size_t start = 0)
{
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

                // locatePattern (source, match, start);       // find pattern
                int l = str.locatePattern(delim);

                if (l == str.length || l == -1)
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
