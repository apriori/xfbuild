/**
        Taken from Defend's engine.util.MT
 */

module xfbuild.MT;

import xfbuild.Exception;

import std.string : format;
import std.exception;
import std.stdio;

version (MultiThreaded) 
{
    import core.atomic;
    import std.parallelism;
    import std.c.process;

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
            result.from     = from;
            result.to       = to;

            if (numPerTask == 0)
            {
                result.numPerTask = (to - from) / 4;

                if (result.numPerTask == 0)  // (to - from) < 4
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

            shared int numLeft;
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

            void theTask(int arg)
            {
                run(arg);                
                atomicOp!"+="(numLeft, -1);
            }

            for (int i = 0; i < numTasks - 1; ++i)
            {
                auto aTask = task(&theTask, i);
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
