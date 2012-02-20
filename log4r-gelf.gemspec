# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "log4r-gelf/version"

Gem::Specification.new do |s|
  s.name        = "log4r-gelf"
  s.version     = Log4r::Gelf::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matt Conway"]
  s.email       = ["matt@conwaysplace.com"]
  s.homepage    = ""
  s.summary     = %q{A Log4r appender for logging to a gelf sink, e.g. the graylog2 server}
  s.description = %q{A Log4r appender for logging to a gelf sink, e.g. the graylog2 server}

  s.rubyforge_project = "log4r-gelf"

  s.files         = %w{
                        Gemfile
                        Rakefile
                        lib/log4r-gelf.rb
                        lib/log4r-gelf/gelf_outputter.rb
                        lib/log4r-gelf/version.rb
                        log4r-gelf.gemspec
                      }
  s.test_files    = []
  s.executables   = []
  s.require_paths = ["lib"]

  s.add_dependency("log4r", '~> 1.0')
  s.add_dependency("gelf", '~> 1.3')

end
