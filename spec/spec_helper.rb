require 'rubygems'
require 'spec'
require 'stringio'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
  # no debugging
end

def capturing_stdout
  saved_stdout = $stdout
  begin
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = saved_stdout
  end
end

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
require 'duplikate'
