# QuickCheckExamples

In this repository Quviq show some example QuickCheck models to help
their QuickCheck users getting started and learn some new things.

You need to have a [Quviq QuickCheck](http://quviq.com/) licence to use these QuickCheck
models. Licences can be ordered from Quviq or are part of your toolbox
when you have Quviq take care of (part of) your testing.

[<img src="http://quickcheck-ci.com/p/Quviq/QuickCheckExamples.svg" alt="Build Status" width="160px">](http://quickcheck-ci.com/p/Quviq/QuickCheckExamples)

## CRUD examples

Testing that you can create, read, update and delete a resource in a
system is a rather common operation. The following examples
demonstrate the basics of how to use a stateful model that keeps track
of the operations performed to the resource.

### CRUD: crud_eqc.erl

 As a simple example, we use files as our resource. We fix two file
 names in advance and have a resource model in which we determine the
 name of the resource (as in key-value pairs, for example).

The data we put in files is generated using the
[eqc_gen:utf8/0](http://quviq.com/documentation/eqc/eqc_gen.html#utf8-0) generator.
This generates a random sequence of utf8 characters, but as can be seen
from the features we record while testing, it will hardly ever create
more than 100 characters. Features are useful to detect whether certain
 things have been tested or when assuring that a certain requirement has
 been covered.

### CRUD where create returns a unique id: crud_unique_id_eqc.erl

This is a model for a resource that, returns a unique identifier when
created. The difference with the above is that we do not know in
advance what name the resource has and in consecutive API calls, we
need to refer to the created resource symbolically "the resource
created in that call".

As a simple example, we use processes as our resources. Each process
contains a value set by its creation. This value can be changed by an
update function and read by sending a message to obtain the value.
Deleting is done brute force by killing the process containing the resource.

The data we put in processes are integers generated using the
[eqc_gen:int/0](http://quviq.com/documentation/eqc/eqc_gen.html#int-0)
generator.

## Dets example

There have been some hard to find race conditions in the Erlang dets
module long ago. After six weeks of traditional testing, these were
not found, but with a 200 lines QuickCheck model, they showed up
immediately. For those with access to scientific literature, the
[full paper](http://doi.acm.org/10.1145/2034654.2034667) explains
the story in more detail. Alternatively you watch
[a video](https://www.youtube.com/watch?v=F6LzB6SdFKA) half way
in (30 min).

The model dets_eqc.erl is provided to show how these races could be
found. It has much similarity with the CRUD models, since dets is just
a data storage.

## Generating Erlang programs

Quviq's QuickCheck can be used to generate programs and contains
the Erlang program generator. This program generator has detected a
number of faults in previous versions of the Erlang compiler. The good
thing when finding such errors is that QuickCheck shrinks the program
to something easy to debug.

For example in [ERL-76](https://bugs.erlang.org/browse/ERL-76) we
reported a compiler error with the following shrunk program:
```erlang
-module(myprog).

second() ->
  catch case second() of
	  #{[] := #{0 := Dont}} when Dont#{0 => second} -> mad
	end.
```

Another example [ERL-150](https://bugs.erlang.org/browse/ERL-150)
reported for OTP-19.0-rc1 shows an internal beam type error.

```erlang
-module(bug).

-compile(export_all).

f(pat) ->
  X = case err of
         ok  -> ok;
         err -> external:call(), 0
      end,
  case X of
    ok  -> ok;
    err -> err;
    0   -> bad
  end.
```

We sincerely hope that Erlang developers are running this property every night
on the compiler to find these before Elixir folks or other folks that
depend on the corners of the compiler bump into such issues.

