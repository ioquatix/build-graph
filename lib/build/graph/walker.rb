# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'set'

require_relative 'edge'
require_relative 'error'

module Build
	module Graph
		# A walker walks over a graph and applies a task to each node.
		class Walker
			def initialize(nodes = Set.new, &block)
				@nodes = nodes
				
				# Node -> Task mapping.
				@tasks = {}
				
				@update = block
				
				# The number of nodes we have touched:
				@count = 0
				
				@outputs = {}
				@dirty = Set.new(@nodes)
				
				@parents = {}
				
				# Failed output paths:
				@failed = Set.new
				
				# The number of failed nodes:
				@failures = 0
			end
			
			attr :nodes
			
			attr :outputs
			
			attr :count
			attr :dirty
			
			attr :parents
			
			# A list of outputs which have failed to generate:
			attr :failed
			
			# The count of nodes which have failed.
			attr :failures
			
			def update(nodes)
				nodes.each do |node|
					@update.call(self, node)
				end
			end
			
			def failed?
				@failures > 0
			end
			
			def wait_on_paths(paths)
				edge = Edge.new
				failed = false
			
				paths.each do |path|
					if @outputs.include? path
						@outputs[path] << edge
					
						edge.increment!
					end
				
					if !failed and @failed.include?(path)
						failed = true
					end
				end
			
				edge.wait || failed
			end
		
			def wait_for_tasks(children)
				edge = Edge.new
			
				children.each do |child|
					if @dirty.include?(child.node)
						edge.increment!
					
						@parents[child.node] ||= []
						@parents[child.node] << edge
					end
				end
			
				edge.wait
			end
			
			def exit(task)
				@count += 1
				
				@dirty.delete(task.node)
				
				# Fail outputs if the node failed:
				if task.failed?
					if task.outputs
						@failed += task.outputs
					end
					
					@failures += 1
				end
				
				# Clean the node's outputs:
				task.outputs.each do |path|
					if edges = @outputs.delete(path)
						edges.each{|edge| edge.traverse(task)}
					end
				end
				
				# Trigger the parent nodes:
				if parents = @parents.delete(task.node)
					parents.each{|edge| edge.traverse(task)}
				end
			end
		end
	end
end
