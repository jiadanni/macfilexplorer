require 'xcodeproj'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

sources_group = project.main_group['MacFileExplorer']['Sources']
unless sources_group
  puts "Sources group not found"
  exit 1
end

# We need to add FileBrowserDragDropHandler.swift
# On disk it is at FileBrowser/UI/FileBrowserDragDropHandler.swift
# So relative to sources group (which is MacFileExplorer/Sources), it is FileBrowser/UI/FileBrowserDragDropHandler.swift

file_path = 'FileBrowser/Extensions/FileBrowserViewController+ContextMenuShim.swift'
filename = 'FileBrowserViewController+ContextMenuShim.swift'

# Check if already exists (by name)
existing = sources_group.recursive_children.find { |c| c.name == filename || c.path.end_with?(filename) }
if existing
  puts "#{filename} already exists at #{existing.path}"
  # Ensure path is correct using our previous logic? 
  # If it exists but path is wrong, it would have been fixed by previous script?
  # Let's just ensure it's in the target.
else
  puts "Adding #{filename}..."
  # Create file reference
  # If Sources group is mapped to MacFileExplorer/Sources, we can add it directly to sources_group with valid relative path?
  # Or should we replicate the group structure in Xcode?
  # User's project seems flat in Xcode (based on previous inspect output).
  # So we just add the file ref to Sources group with the path "FileBrowser/UI/FileBrowserDragDropHandler.swift"
  
  file_ref = sources_group.new_file(file_path)
  
  # Add to target
  target = project.targets.first
  target.source_build_phase.add_file_reference(file_ref)
  
  project.save
  puts "Added #{filename} to project and target."
end
