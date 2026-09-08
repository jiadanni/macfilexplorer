require 'xcodeproj'
require 'pathname'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Sources group
# Assuming structure is Main Group -> MacFileExplorer -> Sources
main_group = project.main_group
app_group = main_group['MacFileExplorer']

unless app_group
  puts "Error: Could not find 'MacFileExplorer' group."
  exit 1
end

sources_group = app_group['Sources']
unless sources_group
  puts "Error: Could not find 'Sources' group."
  exit 1
end

puts "Checking files in Sources group..."

# Define the actual path to Sources directory on disk
# The script is running in the root, so MacFileExplorer/Sources
sources_dir = Pathname.new("MacFileExplorer/Sources")

# Get all files on disk recursively
puts "Scanning disk for files..."
files_on_disk = Dir.glob("#{sources_dir}/**/*.swift").map { |f| Pathname.new(f) }
files_map = {} # filename -> relative_path_from_sources_dir

files_on_disk.each do |full_path|
  relative_path = full_path.relative_path_from(sources_dir)
  filename = full_path.basename.to_s
  files_map[filename] = relative_path.to_s
end

puts "Found #{files_map.size} swift files on disk."

updated_count = 0
not_found_on_disk_count = 0

# Helper to process a group recursively
def process_group(group, sources_dir, files_map)
  count = 0
  
  group.files.each do |file_ref|
    next unless file_ref.path && file_ref.path.end_with?('.swift')
    
    # Current path relative to the group (assuming group path is Sources)
    # If file path is absolute or has different source_tree, this might be complex
    # But usually it's just "File.swift" or "SubDir/File.swift" relative to group.
    
    current_path = file_ref.path
    full_candidate_path = sources_dir.join(current_path)
    
    unless full_candidate_path.exist?
      puts "Missing: #{current_path}"
      filename = File.basename(current_path)
      
      if new_relative_path = files_map[filename]
        puts "  -> Found at: #{new_relative_path}"
        file_ref.path = new_relative_path
        count += 1
      else
        puts "  -> NOT FOUND on disk!"
        # not_found_on_disk_count += 1 # Scope issue, ignoring for now
      end
    end
  end
  
  # Recurse if there are subgroups (though User said it's currently flat in Xcode?)
  group.groups.each do |subgroup|
    count += process_group(subgroup, sources_dir, files_map)
  end
  
  count
end

updated_count = process_group(sources_group, sources_dir, files_map)

if updated_count > 0
  project.save
  puts "Updated #{updated_count} file paths. Project saved."
else
  puts "No files needed updating."
end
