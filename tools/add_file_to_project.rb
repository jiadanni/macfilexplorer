#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Sources group
sources_group = project.main_group.groups.find { |g| g.path == 'MacFileExplorer' }
                        &.groups&.find { |g| g.path == 'Sources' }

if sources_group.nil?
  puts "Could not find Sources group"
  exit 1
end

# Check if file already exists in project
file_path = 'MacFileExplorer/Sources/PermissionsManager.swift'
existing_file = sources_group.files.find { |f| f.path == 'PermissionsManager.swift' }

if existing_file
  puts "PermissionsManager.swift already exists in project"
  exit 0
end

# Add the file reference
file_ref = sources_group.new_file('PermissionsManager.swift')

# Add to build phase
target = project.targets.first
target.source_build_phase.add_file_reference(file_ref)

# Save the project
project.save

puts "Successfully added PermissionsManager.swift to project"
