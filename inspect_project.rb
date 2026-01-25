require 'xcodeproj'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

def print_group(group, level = 0)
  indent = "  " * level
  puts "#{indent}- #{group.display_name} (Path: #{group.path}, SourceTree: #{group.source_tree})"
  group.children.each do |child|
    if child.isa == 'PBXGroup'
      print_group(child, level + 1)
    else
      puts "#{indent}  * #{child.display_name} (Path: #{child.path})"
    end
  end
end

sources = project.main_group['MacFileExplorer']['Sources']
if sources
  puts "Found Sources group"
  # Just print top level of Sources to avoid huge output
  sources.children.first(10).each do |child|
     puts " - #{child.display_name} (Path: #{child.path})"
  end
else
  puts "Sources group not found"
end
