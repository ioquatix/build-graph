# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "build/graph/edge"

describe Build::Graph::Edge do
	let(:edge) {subject.new}
	
	let(:failed_task) do
		task = Object.new
		def task.failed? = true
		task
	end
	
	it "fails if a failed task is traversed" do
		edge.traverse(failed_task)
		expect(edge).to be(:failed?)
	end
	
	it "fails if a failed task is skipped" do
		edge.skip!(failed_task)
		expect(edge).to be(:failed?)
	end
end
