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

# Files to add
files_to_add = [
  'FileBrowserActionHelper.swift',
  'FileBrowserDialogHelper.swift',
  'FileBrowserContextMenuProvider.swift',
  'FileBrowserPreviewPaneCoordinator.swift',
  'FileBrowserViewModeCoordinator.swift',
  'FileBrowserZoomCoordinator.swift',
  'FileBrowserFilterCoordinator.swift',
  'FileBrowserNavigationCoordinator.swift',
  'FileBrowserSelectionCoordinator.swift'
]

target = project.targets.first

files_to_add.each do |filename|
  # Check if file already exists in project
  existing_file = sources_group.files.find { |f| f.path == filename }
  
  if existing_file
    puts "#{filename} already exists in project"
    next
  end
  
  # Add the file reference
  file_ref = sources_group.new_file(filename)
  
  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{filename} to project"
end

# Save the project
project.save

puts "Successfully added all helper and coordinator files to project"
