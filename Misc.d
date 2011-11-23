module xfbuild.Misc;

import std.algorithm : startsWith;
import std.ascii     : isWhite;
import std.string : format;
alias isWhite isSpace;
import std.string : stripLeft;
alias stripLeft triml;

import std.algorithm : countUntil;

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

                if (l == str.length)
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
