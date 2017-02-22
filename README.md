# QuickCheckExamples

In this repository Quviq show some example QuickCheck models to help
their QuickCheck users getting started and learn some new things.

You need to have a [Quviq QuickCheck](http://quviq.com/) licence to use these QuickCheck
models. Licences can be ordered from Quviq or are part of your toolbox
when you have Quviq take care of (part of) your testing.

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
