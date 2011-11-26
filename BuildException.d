/+
 +           Copyright Andrej Mitrovic 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.BuildException;

import std.exception;

// resolve copypaste maddness
mixin template NormalException(string name)
{
    mixin(`
    class ` ~ name ~ ` : Exception
    {
        this(string msg) 
        {
            super(msg);
        }
        
        this(string msg, string file, size_t line, Exception next = null)
        {
            super(msg, file, line, next);
        }
    }`);     
}

mixin NormalException!"BuildException";
mixin NormalException!"ParseException";
