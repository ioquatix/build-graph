# Build::Graph

Build::Graph is a framework for build systems, with specific functionality for dealing with file based processes.

[![Build Status](https://secure.travis-ci.org/ioquatix/build-graph.png)](http://travis-ci.org/ioquatix/build-graph)
[![Code Climate](https://codeclimate.com/github/ioquatix/build-graph.png)](https://codeclimate.com/github/ioquatix/build-graph)
[![Coverage Status](https://coveralls.io/repos/ioquatix/build-graph/badge.svg)](https://coveralls.io/r/ioquatix/build-graph)

## Installation

Add this line to your application's Gemfile:

    gem 'build-graph'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install build-graph

## Usage

A build graph is an abstract set of `[input, process, output]` nodes. A node executes it's proces within the context of a `Task` which represents a specific set of inputs and outputs and is managed within a `Walker` that walks over graph nodes, regenerating tasks where required. If inputs or outputs change (i.e. become dirty), the task is destroyed and regenerated.

A `Walker` is used to traverse the build graph once. As it walks over the graph it builds a set of `Edge` relationships between nodes and only traverses relationships which are complete `Walker#wait_on_paths`. Parent nodes also wait until all their children are complete `Walker#wait_on_nodes` It also keeps track of failures `Walker#failed?` and fails all dependencies of a node.

A `Task` is instantiated once per node when traversing the graph. The task represents a specific process being applied to the graph, e.g. build, clean, etc. It is responsible for actually performing any real actions and providing the methods to do so. A `Task` contains all details about the specific graph state at that point in time, e.g. `Task#children` and updating the node state in `Task#exit`. Statistics on the build graph are also captured through `Task` and `Walker`, e.g. number of nodes visited, etc.

### Inputs and Outputs

Inputs to a node should be all on-disk state and any additional parameters which cause it's behavior to produce different results.

Outputs from a node should be all files that are generated directly by the processes within the node and sometimes it's children.

### Dirty Propagation

A `Node` has a set of `#inputs` and `#outputs` but these are abstract. A `Task`, at the time of execution, captures it's inputs and outputs and these may be monitored for changes in real time. The simplest way to cause a task to regenerate is to simply remove it from the existing graph and it will be regenerated.

File changes are currently detected using `File::mtime` as this is generally a good trade off between efficiency and accuracy.

When a task is marked as dirty, it also marks all it's outputs as being dirty, which in cause could mark other tasks as dirty. This is the mechanism for which dirtiness propagates through the graph. The walker should only have to traverse the graph once to build it completely. If multiple updates are required (i.e. buidling one part of the graph implicitly dirties another part of the graph), the specification of the graph is incomplete and this may lead to problems within the build graph.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2012, 2014, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
