#!/usr/bin/env ruby

require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

task :default => 'spec'
  
desc "Run specifications"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = FileList[(ENV['FILES'] || 'spec/**/*_spec.rb')]
end