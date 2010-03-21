require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "uki"
    gem.summary = %Q{uki development tools}
    gem.description = %Q{Project creation, dev server, testing, building for uki apps}
    gem.email = "voloko@gmail.com"
    gem.homepage = "http://github.com/voloko/uki"
    gem.authors = ["Vladimir Kolesnikov"]

    gem.add_runtime_dependency(%q<sinatra>, [">= 0"])
    gem.add_runtime_dependency(%q<commander>, [">= 4.0.1"])
    gem.add_runtime_dependency(%q<jspec>, [">= 3.3.2"])
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end