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

require 'rainbow'
require 'system'
require 'fiber'

module Build
	module System
		# A pool is a group of tasks which can be run asynchrnously using fibers. Someone must call #wait to ensure that all fibers eventuall resume.
		class Pool
			def self.processor_count
				::System::CPU.count
			end
	
			class Command
				def initialize(arguments, options, fiber = Fiber.current)
					@arguments = arguments
					@options = options
				
					@fiber = fiber
				end
			
				attr :arguments
				attr :options
			
				def run(options = {})
					puts Rainbow("Running #{@arguments.inspect} options: #{@options.merge(options).inspect}").blue
				
					Process.spawn(*@arguments, @options.merge(options))
				end
			
				def resume(*arguments)
					@fiber.resume(*arguments)
				end
			end
	
			def initialize(options = {})
				@commands = []
				@limit = options[:limit] || Pool.processor_count
			
				@running = {}
				@fiber = nil
			
				@pgid = true
			end
		
			attr :running
		
			def run(*arguments)
				options = Hash === arguments.last ? arguments.pop : {}
				arguments = arguments.flatten.collect &:to_s
			
				@commands << Command.new(arguments, options)
			
				schedule!
			
				Fiber.yield
			end
		
			def schedule!
				while @running.size < @limit and @commands.size > 0
					command = @commands.shift
				
					if @running.size == 0
						pid = command.run(:pgroup => true)
						@pgid = Process.getpgid(pid)
					else
						pid = command.run(:pgroup => @pgid)
					end
				
					@running[pid] = command
				end
			end
	
			def wait
				while @running.size > 0
					# Wait for processes in this group:
					pid, status = Process.wait2(-@pgid)
				
					command = @running.delete(pid)
				
					schedule!
				
					command.resume(status)
				end
			end
		end
	
		module FakePool
			def self.wait
			end
		
			def self.run(*arguments)
				0
			end
		end
	end
end
