/**
        Taken from Defend's engine.util.MT
 */

module xfbuild.MT;

import std.string : format;
import std.stdio;

version (MultiThreaded)
{
    import core.atomic;
}

// todo: implement a proper logger
struct TraceLog
{
    string error;
    
    void formatln(string frm, Exception exception)
    {
        error ~= format(frm, exception) ~ " ";
    }
}

__gshared TraceLog Trace;

version (MultiThreaded) 
{
    import std.parallelism;
    import std.c.process;
    
    private 
    {
        import xfbuild.BuildException;
    }

    struct MTFor
    {
        TaskPool taskPool;
        int from, to;
        int numPerTask;

        static MTFor opCall(TaskPool taskPool, int from, int to, int numPerTask = 0)
        {
            assert(to >= from);

            MTFor result;
            result.taskPool = taskPool;
            result.from       = from;
            result.to         = to;

            if (numPerTask == 0)
            {
                result.numPerTask = (to - from) / 4;

                if (result.numPerTask == 0)                // (to - from) < 4
                    result.numPerTask = 1;
            }
            else
                result.numPerTask = numPerTask;

            return result;
        }

        int opApply(int delegate(ref int) dg)
        {
            if (to == from)
                return 0;

            assert(numPerTask > 0);

            int numLeft;             // was Atomic!(int)
            int numTasks = (to - from) / numPerTask;

            assert(numTasks > 0);
            atomicStore(numLeft, numTasks - 1);

            void run(int idx)
            {
                int i, start;
                i = start = idx * numPerTask;

                while (i < to && i - start < numPerTask)
                {
                    dg(i);
                    ++i;
                }
            }

            void theTask(void* arg)
            {
                try
                {
                    run(cast(int)arg);
                }
                catch (BuildException e)
                {
                    writefln("Build failed: %s", e);
                    exit(1);
                }
                catch (Exception e)
                {
                    writefln("%s", e);
                    exit(1);
                }
                
                atomicOp!"+="(numLeft, -1);
            }

            for (int i = 0; i < numTasks - 1; ++i)
            {
                auto aTask = task(&theTask, cast(void*)i);
                taskPool.put(aTask);
            }

            run(numTasks - 1);

            while (atomicLoad(numLeft) > 0)
            {
            }

            return 0;
        }
    }


    MTFor mtFor(TaskPool taskPool, int from, int to, int numPerTask = 0)
    {
        return MTFor(taskPool, from, to, numPerTask);
    }
}
