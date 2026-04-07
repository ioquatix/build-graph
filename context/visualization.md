# Visualization

This guide explains how to use {ruby Build::Graph::Visualization} to generate Mermaid flowchart diagrams from a build graph.

## Overview

When debugging or documenting a build graph, it is useful to see the relationships between inputs and outputs visually. `Build::Graph::Visualization` produces a [Mermaid](https://mermaid.js.org) `flowchart LR` diagram from a completed {ruby Build::Graph::Walker}, showing each file as a node and each build step as a directed edge.

## Usage

After running a walker, pass it to {ruby Build::Graph::Visualization#generate}:

~~~ ruby
require "build/graph/visualization"

walker = Build::Graph::Walker.new do |walker, node|
  task = Build::Graph::Task.new(walker, node)
  task.visit do
    # perform the actual build step here
  end
end

walker.update(root_node)

visualization = Build::Graph::Visualization.new
diagram = visualization.generate(walker)

puts diagram
~~~

The output is a Mermaid diagram string that can be embedded in documentation, printed to the terminal, or written to a file:

~~~
flowchart LR
    _src_main_c[main.c]
    _obj_main_o[main.o]
    _src_main_c --> _obj_main_o
    _obj_main_o[main.o]
    _bin_program[program]
    _obj_main_o --> _bin_program
~~~

## Traversal Without Building

To generate a diagram without actually executing any build steps (e.g. for documentation or dry-run inspection), use {ruby Build::Graph::Task#traverse} instead of `visit` in the walker block:

~~~ ruby
walker = Build::Graph::Walker.new do |walker, node|
  task = Build::Graph::Task.new(walker, node)
  task.traverse
end

walker.update(root_node)

diagram = Build::Graph::Visualization.new.generate(walker)
~~~

Unlike `visit`, `traverse` skips input validation and does not require any files to exist on disk. It registers all node outputs with the walker so that dependent nodes can still be resolved correctly.

However, `traverse` only follows **declared** edges — the inputs and outputs as written in the build definition. Some build systems discover additional dependencies at build time (for example, a C compiler producing a `.d` file that lists every header it included). Those discovered edges will not appear in the diagram.

## Complete Graph Visualization

To get a complete and accurate picture of the graph, including any dependencies discovered during execution, use {ruby Build::Graph::Task#visit} with an empty block instead of `traverse`:

~~~ ruby
walker = Build::Graph::Walker.new do |walker, node|
  task = Build::Graph::Task.new(walker, node)
  task.visit do
    # perform the actual build step here, e.g. compile, link, etc.
  end
end

walker.update(root_node)

diagram = Build::Graph::Visualization.new.generate(walker)
~~~

This executes the build steps and captures the full set of inputs and outputs — including any that are only known after running the task — giving a diagram that accurately reflects what was built and why.
