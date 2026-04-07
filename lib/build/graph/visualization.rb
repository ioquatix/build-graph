# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

module Build
	module Graph
		# Generates Mermaid flowchart visualizations of build graphs.
		class Visualization
			# Convert a path to a valid Mermaid node ID.
			# @parameter path [String] The path to sanitize.
			# @returns [String] A sanitized identifier safe for use in Mermaid diagrams.
			def sanitize_id(path)
				path.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
			end
			
			# Generate a Mermaid flowchart diagram for a completed walker.
			# @parameter walker [Walker] The completed walker containing tasks.
			# @returns [String] A Mermaid flowchart diagram in text format.
			def generate(walker)
				lines = ["flowchart LR"]
				
				walker.tasks.each do |node, task|
					next unless task.inputs && task.outputs
					next if task.outputs.equal?(:inherit)
					
					input_ids = task.inputs.to_a.map { |path| sanitize_id(path) }
					output_ids = task.outputs.to_a.map { |path| sanitize_id(path) }
					
					task.inputs.each do |path|
						lines << "    #{sanitize_id(path)}[#{path.basename}]"
					end
					
					task.outputs.each do |path|
						lines << "    #{sanitize_id(path)}[#{path.basename}]"
					end
					
					label = node.respond_to?(:title) ? node.title.to_s : nil
					
					input_ids.each do |input_id|
						output_ids.each do |output_id|
							if label && !label.empty?
								lines << "    #{input_id} -->|#{label}| #{output_id}"
							else
								lines << "    #{input_id} --> #{output_id}"
							end
						end
					end
				end
				
				return lines.join("\n")
			end
		end
	end
end
