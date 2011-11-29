/+
 +           Copyright Andrej Mitrovic 2011.
 +       Copyright Tomasz Stachowiak 2009 - 2011.
 +  Distributed under the Boost Software License, Version 1.0.
 +     (See accompanying file LICENSE_1_0.txt or copy at
 +           http://www.boost.org/LICENSE_1_0.txt)
 +/
module xfbuild.Exception;

import std.exception;

class BuildException : Exception
{
    string errorMsg;
    this(string msg) 
    {
        errorMsg = msg;
        super(msg);
    }
    
    this(string msg, string file, size_t line, Exception next = null)
    {
        errorMsg = msg;
        super(msg, file, line, next);
    }    
}

string ExceptionImpl(string name)
{
    return(`
    class ` ~ name ~ ` : BuildException
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

mixin(ExceptionImpl("CompilerError"));
mixin(ExceptionImpl("ModuleException"));
mixin(ExceptionImpl("ParseException"));
mixin(ExceptionImpl("ProcessExecutionException"));
