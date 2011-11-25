/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.BuildException;

import std.exception;

class BuildException : Exception
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

class ParseException : Exception
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
