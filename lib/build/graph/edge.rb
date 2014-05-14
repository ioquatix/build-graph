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

require_relative 'error'

module Build
	module Graph
		# Represents an input to a graph node, with count inputs.
		class Edge
			def initialize(count = 0)
				@fiber = Fiber.current
				@count = count
			
				@failed = []
			end
		
			attr :failed
		
			attr :fiber
			attr :count
		
			def wait
				if @count > 0
					Fiber.yield
				end
			
				failed?
			end
		
			attr :failed
		
			def failed?
				@failed.size != 0
			end
		
			def traverse(node)
				@count -= 1
			
				if node.failed?
					@failed << node
				end
			
				if @count == 0
					@fiber.resume
				end
			end
		
			def increment!
				@count += 1
			end
		end
	end
end
