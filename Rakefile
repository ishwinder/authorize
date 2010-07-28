require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the authorize plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test/test'
  t.pattern = 'test/test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the authorize plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Authorize'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end