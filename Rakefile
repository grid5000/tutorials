ROOT_DIR = File.dirname(__FILE__)
BUILD_DIR = File.join(ROOT_DIR, "build")

desc "Clean up everything in #{BUILD_DIR}."
task :clean do
  rm_rf BUILD_DIR
end


namespace :build do
  task :setup do
    mkdir_p BUILD_DIR
  end
  
  desc "Build the HTML files for the API tutorials."
  task :api => :setup do
    Dir.chdir(ROOT_DIR) do
      sh "rocco #{File.join("api", "**", "*.sh")} #{File.join("api", "**", "*.rb")} -o #{BUILD_DIR}"
    end
  end
end

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
