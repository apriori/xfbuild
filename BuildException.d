module xfbuild.BuildException;

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
