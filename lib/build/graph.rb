
require 'build/files/monitor'

require 'build/error'
require 'build/node'
require 'build/walker'
require 'build/edge'

module Build
	class Graph < Files::Monitor
		def initialize
			super
			
			@nodes = {}
			
			build_graph!
		end
		
		attr :nodes
		
		# You need to override this to traverse the top nodes as required:
		def traverse!(walker)
			#Array(top).each do |node|
			#	node.update!(walker)
			#end
		end
		
		def walk(&block)
			Walker.new(self, &block)
		end
		
		def build_graph!
			# We build the graph without doing any actual execution:
			nodes = []
			
			walker = walk do |walker, node|
				nodes << node
				
				yield walker, node
			end
			
			traverse! walker
			
			# We should update the status of all nodes in the graph once we've traversed the graph.
			nodes.each do |node|
				node.update_status!
			end
		end
		
		def update_with_log
			puts Rainbow("*** Graph update traversal ***").green
			
			start_time = Time.now
			
			walker = update!
		ensure
			end_time = Time.now
			elapsed_time = end_time - start_time
			
			$stdout.flush
			$stderr.puts Rainbow("Graph Update Time: %0.3fs" % elapsed_time).magenta
		end
		
		def update!
			walker = walk do |walker, node|
				yield walker, node
			end
			
			traverse! walker
			
			return walker
		end
	end
end
