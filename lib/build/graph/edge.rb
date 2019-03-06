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

require 'fiber'

module Build
	module Graph
		# Represents a set of inputs to a graph node.
		class Edge
			def initialize(count = 0)
				@fiber = Fiber.current
				
				# The number of inputs we are waiting for:
				@count = count
				@vertices = 0
				
				@failed = []
			end
			
			attr :failed
			
			attr :fiber
			attr :count
			
			# Wait until all inputs to the edge have been traversed. Returns false if failed?
			def wait
				if @count > 0
					Fiber.yield
				end
				
				succeeded?
			end
			
			def failed?
				@failed.size != 0
			end
			
			def succeeded?
				@failed.size == 0
			end
			
			# Traverse the edge, mark the edge as failed if the source was also failed.
			def traverse(task)
				@count -= 1
				
				$stderr.puts "edge #{self}.traverse @count = #{@count}"
				
				# The entire edge fails if any individual task fails.
				if task.failed?
					@failed << task
				end
				
				if @count == 0
					$stderr.puts "edge #{self}.traverse resume fiber"
					@fiber.resume
				end
			end
			
			# This is called in the case that a parent fails to complete because a child task has failed.
			def skip!(task)
				@vertices += 1
				
				if task.failed?
					@failed << task
				end
			end
			
			# Increase the number of traversals we are waiting for.
			def increment!
				@vertices += 1
				@count += 1
			end
		end
	end
end
