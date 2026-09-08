require 'xcodeproj'
require 'pathname'

project_path = 'MacFileExplorer.xcodeproj'
project = Xcodeproj::Project.open(project_path)

sources_dir = Pathname.new("MacFileExplorer/Sources")
main_group = project.main_group
app_group = main_group['MacFileExplorer']
sources_group = app_group['Sources']

# Get all files on disk recursively
files_on_disk = Dir.glob("#{sources_dir}/**/*.swift").map { |f| Pathname.new(f) }

# Get all existing file references in the project (recursive)
existing_files = project.files.select { |f| f.path && f.path.end_with?('.swift') }
existing_paths = existing_files.map do |file_ref|
    # Most file paths are relative to their group.
    # We'll just check if the basename is there, but a more robust way is needed.
    # Let's use the actual filename as a key for now if we want to avoid duplicates.
    File.basename(file_ref.path)
end

added_count = 0
target = project.targets.first

files_on_disk.each do |full_path|
    filename = full_path.basename.to_s
    # Skip if basename is already in project (simplified check)
    next if existing_paths.include?(filename)
    
    relative_path = full_path.relative_path_from(sources_dir)
    puts "Adding missing file: #{relative_path}"
    
    file_ref = sources_group.new_file(relative_path.to_s)
    target.source_build_phase.add_file_reference(file_ref)
    added_count += 1
end

if added_count > 0
    project.save
    puts "Successfully added #{added_count} files to the project."
else
    puts "No missing files found."
end
