require 'rubygems'
require 'spec'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
  # no debugging
end

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
require 'duplikate'