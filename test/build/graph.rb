# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2014-2026, by Samuel Williams.

require "process_graph"

describe Build::Graph do
	let(:group) {Process::Group.new}
	
	it "shouldn't update mtime" do
		test_glob = Build::Files::Glob.new(__dir__, "graph/*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["graph/listing.txt"])
		
		FileUtils.rm_f listing_output.to_a
		
		walker = Build::Graph::Walker.for(ProcessTask, group)
		
		top = ProcessNode.top do
			process test_glob, listing_output do
				run("ls", "-la", *inputs, :out => outputs.first.for_writing)
			end
		end
		
		group.wait do
			walker.update(top)
		end
		
		first_modified_time = listing_output.first.modified_time
		
		group.wait do
			walker.update(top)
		end
		
		# The output file shouldn't have been changed because it already exists and the input files haven't changed either:
		second_modified_time = listing_output.first.modified_time
		
		expect((second_modified_time.to_f - first_modified_time.to_f).abs).to be <= 0.001
		
		FileUtils.rm_f listing_output.to_a
		walker.monitor.update(listing_output.roots)
		
		group.wait do
			walker.update(top)
		end
		
		expect(listing_output.first.modified_time).to be >= first_modified_time
		
		FileUtils.rm_f listing_output.to_a
	end
	
	it "should compile program and respond to changes in source code" do
		program_root = Build::Files::Path.join(__dir__, ".program")
		code_glob = Build::Files::Glob.new(program_root, "*.cpp")
		program_path = Build::Files::Path.join(program_root, "dictionary-sort")
		
		walker = Build::Graph::Walker.for(ProcessTask, group)
		
		top = ProcessNode.top do
			process code_glob, program_path do
				object_files = inputs.with(extension: ".o") do |input_path, output_path|
					depfile_path = input_path + ".d"
					
					dependencies = Build::Files::Paths.new(input_path)
					
					if File.exist? depfile_path
						depfile = Build::Makefile.load_file(depfile_path)
						
						dependencies = depfile[output_path] || dependencies
					end
					
					process dependencies, output_path do
						run("clang++", "-MMD", "-O3",
							"-o", output_path.shortest_path(input_path.root),
							"-c", input_path.relative_path, "-std=c++11",
							chdir: input_path.root
						)
					end
				end
				
				process object_files, program_path do
					run("clang++", "-O3", "-o", program_path, *object_files.to_a, "-lm", "-pthread")
				end
			end
			
			process program_path do
				run("./" + program_path.relative_path, chdir: program_path.root)
			end
		end
		
		group.wait do
			walker.update(top)
		end
		
		expect(program_path.exist?).to be == true
		expect(code_glob.first.modified_time).to be <= program_path.modified_time
	end
	
	it "should copy files incrementally" do
		program_root = Build::Files::Path.join(__dir__, ".program")
		files = Build::Files::Glob.new(program_root, "*.cpp")
		destination = Build::Files::Path.new(__dir__) + ".program/tmp"
		
		walker = Build::Graph::Walker.for(ProcessTask, group)
		
		top = ProcessNode.top files do
			mkpath destination
			
			inputs.each do |source_path|
				destination_path = source_path.rebase(destination)
				
				process source_path, destination_path do
					install inputs.first, outputs.first
				end
			end
		end
		
		mutex = Mutex.new
		files_deleted = false
		
		thread = Thread.new do
			sleep 1
			
			mutex.synchronize do
				destination.glob("*.cpp").delete
				
				files_deleted = true
			end
		end
		
		walker.run do
			mutex.synchronize do
				group.wait do
					walker.update(top)
				end
			end
			
			break if files_deleted
		end
		
		thread.join
		
		expect(destination.exist?).to be == true
		expect(destination.glob("*.cpp").count).to be == 2
		
		destination.delete
	end
end
