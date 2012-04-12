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

