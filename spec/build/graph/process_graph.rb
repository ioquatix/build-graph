
require 'process/group'
require 'build/files'
require 'build/graph'

require 'console/event/spawn'

class ProcessNode < Build::Graph::Node
	def initialize(inputs, outputs, block, title: nil)
		super(inputs, outputs)
		
		if title
			@title = title
		else
			@title = block.source_location
		end
		
		@block = block
	end
	
	def == other
		super and
			@title == other.title and
			@block == other.block
	end
	
	def hash
		super ^ @title.hash ^ @block.hash
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
	
	class CommandError < RuntimeError
		def initialize(command, status)
			@command = command
			@status = status
			
			super "#{command.join(' ')} failed: #{status}!"
		end
	end
	
	def run(*arguments, **options)
		if wet?
			@walker.logger.debug(self) {Console::Event::Spawn.for(*arguments, **options)}
			
			status = @group.spawn(*arguments, **options)
			
			if status != 0
				raise CommandError.new(arguments, status)
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
