
require 'process/group'
require 'build/files'
require 'build/graph'

require 'event/shell'

class ProcessNode < Build::Graph::Node
	def initialize(inputs, outputs, block, title: nil)
		super(inputs, outputs, block.source_location)
		
		if title
			@title = title
		else
			@title = self.process
		end
		
		@block = block
	end
	
	def evaluate(context)
		context.instance_eval(&@block)
	end
	
	attr :title
end

class ProcessTask < Build::Graph::Task
	def initialize(walker, node, group)
		super(walker, node)
		
		@group = group
	end
	
	def process(inputs, outputs = :inherit, **options, &block)
		inputs = Build::Files::List.coerce(inputs)
		outputs = Build::Files::List.coerce(outputs) unless outputs.kind_of? Symbol
		
		node = ProcessNode.new(inputs, outputs, block, **options)
		
		self.invoke(node)
	end
	
	def wet?
		@node.dirty?
	end
	
	def run(*arguments)
		if wet?
			@walker.logger.debug(self) {Event::Shell.for(*arguments)}
			
			status = @group.spawn(*arguments)
			
			if status != 0
				raise CommandError.new(status)
			end
		end
	end
	
	def mkpath(*args)
		return unless wet?
		
		FileUtils.mkpath(*args)
	end
	
	def install(*args)
		return unless wet?
		
		FileUtils.install(*args)
	end
	
	# This function is called to finish the invocation of the task within the graph.
	# There are two possible ways this function can generally proceed.
	# 1/ The node this task is running for is clean, and thus no actual processing needs to take place, but children should probably be executed.
	# 2/ The node this task is running for is dirty, and the execution of commands should work as expected.
	def update
		@node.evaluate(self)
	end
end
