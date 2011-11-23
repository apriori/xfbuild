/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how sets can be used.
 */
import dcollections.HashSet;
import dcollections.HashMap;
import dcollections.TreeSet;
import dcollections.ArrayList;

import std.stdio;
import std.conv;

/+ void print(Iterator!(Widget) s, string message)
   {
    write(message ~ " [");

    foreach(i; s)
    {
        write(" ", i);
    }

    writeln(" ]");
   } +/

/+
   class Widget
   {
    int x;
    this(int x) { this.x = x; }
    string toString() { return "Widget(" ~ to!string(x) ~ ")"; }
   }

   class State {}

   void main()
   {
    /+ auto w1 = new Widget(1);
    auto w2 = new Widget(2);

    auto set = new HashSet!(Widget);
    set.add(w1);
    set.add(w2);

    set.remove(w1);
    assert(set.contains(w2));
    assert(!set.contains(w1));
    foreach (x; set)
    {
        writeln(x);
    } +/

    auto hashMap = new HashMap!(Widget, State);
    auto widget = new Widget(1);
    hashMap[widget] = new State;

    hashMap.remove(widget);
    hashMap.remove(widget);
   }
 +/

class Widget
{
    int x;
    this(int x) { this.x = x; }
    string toString() { return "Widget(" ~ to!string(x) ~ ")"; }
}

void main()
{
    auto tset = new TreeSet!(Widget);
    
    tset.add(new Widget(1));
    tset.add(new Widget(2));
    tset.add(new Widget(3));
    
    foreach (widget; tset)
    {
        writeln(widget);
    }
}
