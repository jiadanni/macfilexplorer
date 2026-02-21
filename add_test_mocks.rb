#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the test target
test_target = project.targets.find { |t| t.name == 'MacFileExplorerTests' }
if test_target.nil?
  puts "Could not find MacFileExplorerTests target"
  exit 1
end

# Find the test group
tests_group = project.main_group.groups.find { |g| g.path == 'MacFileExplorerTests' }
if tests_group.nil?
  puts "Could not find MacFileExplorerTests group"
  exit 1
end

# Find or create Support subgroup
support_group = tests_group.groups.find { |g| g.path == 'Support' }
if support_group.nil?
  support_group = tests_group.new_group('Support', 'Support')
  puts "Created Support group"
end

# Files to add
files_to_add = ['MockColorManager.swift', 'MockPermissionsManager.swift']

files_to_add.each do |filename|
  existing = support_group.files.find { |f| f.path == filename }
  if existing
    puts "#{filename} already in project"
    next
  end
  
  file_ref = support_group.new_file(filename)
  test_target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename}"
end

project.save
puts "Done"
