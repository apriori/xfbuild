module test;

import std.stdio;
import core.thread;

void main()
{
	Thread.sleep(dur!"msecs"(500));
    writeln("done");
}

