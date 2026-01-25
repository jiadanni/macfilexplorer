#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files to remove
files_to_remove = ARGV

if files_to_remove.empty?
  puts "Usage: ruby remove_missing_files.rb <file1> <file2> ..."
  exit 1
end

target = project.targets.first
removed_count = 0

files_to_remove.each do |filename|
  # Find all file references with this name
  file_refs = project.files.select { |f| f.path && f.path.include?(filename) }
  
  file_refs.each do |file_ref|
    puts "Removing #{file_ref.path}..."
    
    # Remove from all build phases
    target.build_phases.each do |phase|
      if phase.respond_to?(:remove_file_reference)
        phase.remove_file_reference(file_ref)
      end
    end
    
    # Remove from project
    file_ref.remove_from_project
    removed_count += 1
  end
end

if removed_count > 0
  project.save
  puts "Successfully removed #{removed_count} file reference(s) from project"
else
  puts "No files found to remove"
end
