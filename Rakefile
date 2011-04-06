ROOT_DIR = File.dirname(__FILE__)
BUILD_DIR = File.join(ROOT_DIR, "build")

desc "Copy every file from #{BUILD_DIR} into the root dir, preserving hierarchy."
task :copy do
  Dir.chdir(ROOT_DIR) do
    Dir[File.join(BUILD_DIR, "api", "**", "*.html")].each do |file|
      destination = File.join(
        ROOT_DIR, 
        File.dirname(file).gsub(BUILD_DIR, '')
      )
      unless File.directory?(destination)
        mkdir_p destination
      end
      cp file, destination
    end
  end
end