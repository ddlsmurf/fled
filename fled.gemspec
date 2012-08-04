version = $1 if File.read(File.join(File.dirname(__FILE__), "lib/fled.rb")) =~ /VERSION = '([^']+)'/
raise RuntimeError, "Error, could not read version from source" unless version
Gem::Specification.new do |s|
  s.name        = 'fled'
  s.version     = version
  s.date        = '2012-07-31'
  s.summary     = "FlEd lets you edit file names and paths in your favourite editor"
  s.description = "Generate a list of files, edit it, then print a bash script with " +
    "the appropriate commands"
  s.executables << 'fled'
  s.authors     = ["Eric Doughty-Papassideris"]
  s.files       = Dir["lib/**/*.rb", "bin/*", "tests/*.rb", "README.md"]
  s.homepage    =
    'http://github.com/ddlsmurf/fled'
end