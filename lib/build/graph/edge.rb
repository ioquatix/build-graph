# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2014-2019, by Samuel Williams.

require "fiber"

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
				
				# The entire edge fails if any individual task fails.
				if task.failed?
					@failed << task
				end
				
				if @count == 0
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
