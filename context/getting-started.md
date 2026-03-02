# Getting Started

This guide explains how to use `build-graph` to build a dependency graph for file-based build systems.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add build-graph
~~~

Or install it directly:

~~~ bash
$ gem install build-graph
~~~

## Usage

A build graph is an abstract set of `[input, process, output]` nodes. A node executes its process within the context of a `Task` which represents a specific set of inputs and outputs and is managed within a `Walker` that walks over graph nodes, regenerating tasks where required. If inputs or outputs change (i.e. become dirty), the old task is nullified.

A `Walker` is used to traverse the build graph once. As it walks over the graph it builds a set of `Edge` relationships between nodes and only traverses relationships which are complete (`Walker#wait_on_paths`). Parent nodes also wait until all their children are complete (`Walker#wait_on_nodes`). It also keeps track of failures (`Walker#failed?`) and fails all dependencies of a node.

A `Task` is instantiated once per node when traversing the graph. The task represents a specific process being applied to the graph, e.g. build, clean, etc. It is responsible for actually performing any real actions and providing the methods to do so. A `Task` contains all details about the specific graph state at that point in time, e.g. `Task#children` and updating the node state in `Task#exit`. Statistics on the build graph are also captured through `Task` and `Walker`, e.g. number of nodes visited, etc.

### Inputs and Outputs

Inputs to a node should be all on-disk state and any additional parameters which cause its behaviour to produce different results.

Outputs from a node should be all files that are generated directly by the processes within the node and sometimes its children.

### Dirty Propagation

A `Node` has a set of `#inputs` and `#outputs` but these are abstract. For example, `#outputs` could be `:inherit` which means that the node symbolically has all the outputs of all its direct children. A `Task`, at the time of execution, captures its inputs and outputs and these may be monitored for changes in real time.

File changes are currently detected using `File::mtime` as this is generally a good trade off between efficiency and accuracy.

When a task is marked as dirty, it also marks all its outputs as being dirty, which in turn could mark other tasks as dirty. This is the mechanism by which dirtiness propagates through the graph. The walker should only have to traverse the graph once to build it completely. If multiple updates are required (i.e. building one part of the graph implicitly dirties another part of the graph), the specification of the graph is incomplete and this may lead to problems within the build graph.

### Example Graph

~~~ ruby
target("Library/UnitTest", [] => :inherit) do
	library([UnitTest.cpp] => "UnitTest.a") do
		compile([UnitTest.cpp] => "UnitTest.o")
		link([UnitTest.o] => "libUnitTest.a")
	end
	
	copy headers: ["UnitTest.hpp"]
	
	# Outputs become libUnitTest.a and UnitTest.hpp
end

target("Executable/UnitTest", [] => :inherit) do
	depends("Library/UnitTest")
	
	executable("main.cpp" => "UnitTest") do
		compile("main.cpp" => "main.o")
		link(["main.o", "libUnitTest.a"] => "UnitTest")
	end
	
	# Outputs become UnitTest
end
~~~
