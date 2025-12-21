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

# Coordinators to remove (they have integration issues)
coordinators_to_remove = [
  'FileBrowserContextMenuProvider.swift',
  'FileBrowserPreviewPaneCoordinator.swift',
  'FileBrowserViewModeCoordinator.swift',
  'FileBrowserZoomCoordinator.swift',
  'FileBrowserFilterCoordinator.swift',
  'FileBrowserNavigationCoordinator.swift',
  'FileBrowserSelectionCoordinator.swift'
]

target = project.targets.first

coordinators_to_remove.each do |filename|
  # Find the file in the project
  file_ref = sources_group.files.find { |f| f.path == filename }
  
  if file_ref.nil?
    puts "#{filename} not found in project"
    next
  end
  
  # Remove from build phase
  target.source_build_phase.remove_file_reference(file_ref) if target.source_build_phase
  
  # Remove from group
  file_ref.remove_from_project
  puts "Removed #{filename} from project"
end

# Save the project
project.save

puts "Successfully removed coordinators from project"
