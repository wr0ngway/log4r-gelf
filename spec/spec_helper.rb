require 'rspec'
require 'log4r-gelf'
require 'log4r'
require 'log4r/yamlconfigurator'

def deep_copy(obj)
  Marshal.load(Marshal.dump(obj))
end
