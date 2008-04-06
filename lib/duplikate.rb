require 'pathname'
require 'fileutils'
class Duplikate
  attr_accessor :source, :destination
  attr_reader :deleted_files, :deleted_directories, :added_files, :added_directories, :existing_files, :commands, :ignore_patterns

  # Processes the differences between the given source and destination
  # paths.  The returned Duplikate object has the *_directories and *_files
  # arrays filled out.  If you don't want to store the existing_files,
  # pass a block to perform custom actions on them.
  #
  # NOTE: At this point, nothing has been done to either path.
  #
  def self.process(source, dest, options = nil)
    dupe = new(source, dest, options)
    dupe.process
    dupe
  end
  
  # Display the commands that +execute+ would execute.
  def self.dry_run(source, dest, options = nil)
    dupe = new(source, dest, options)
    dupe.dry_run
    dupe
  end
  
  # Actually syncs the source path to the destination path.  This 
  # calls #process if needed, and then:
  #
  #   * Adds new files to the destination path
  #   * Copies all existing files to pick up any changes
  #   * Remove old files from the destination path.
  #
  # After this, it attempts to commit the destination svn repo.
  # You should have a clean working copy for this to work properly.
  def self.execute(message, source, dest, options = nil)
    dupe = new(source, dest, options)
    dupe.execute(message)
    dupe
  end

  # Print the names of files and directories that would be added or
  # deleted.
  def self.report(source, dest, options = nil)
    dupe = new(source, dest, options)
    dupe.report
    dupe
  end
  
  def initialize(source, dest, options = nil)
    @options = options || {}
    @debug   = @options[:debug]
    @source, @destination = Pathname.new(source), Pathname.new(dest)
    @inverse = self.class.new(dest, source, @options.merge(:is_inverse => true)) unless @options[:is_inverse]
    @ignore_patterns = [/^\.(git|svn)?\.?$/]
  end
  
  # Ignores paths that match one of the +patterns+, where each pattern
  # is either a String or Regexp
  def ignore(*patterns)
    @ignore_patterns += patterns
  end
  
  def process
    @deleted_files, @deleted_directories, @added_files, @added_directories, @existing_files = [], [], [], [], []
    if @inverse
      puts "PROCESSING INVERSE" if @debug
      @inverse.process
      @deleted_files       = @inverse.added_files
      @deleted_directories = @inverse.added_directories
    else
      puts "PROCESSING" if @debug
    end
    process_path
  end
  
  def dry_run(msg="<commit message>")
    execute(msg, true)
    puts commands.join("\n")
  end
  
  def execute(message, test_mode = false)
    process if @existing_files.nil?
    unless test_mode
      (@added_files + @added_directories + @existing_files).each do |file|
        FileUtils.cp_r(@source + file, @destination + File.dirname(file))
      end
      FileUtils.rm_rf((@deleted_files + @deleted_directories).collect! { |f| @destination + f })
    end
    @commands = []
    (@added_files + @added_directories).each do |added|
      @commands << "add #{added}"
    end
    (@deleted_files + @deleted_directories).each do |deleted|
      @commands << "rm #{deleted}"
    end
    @commands << "ci -m '#{message}'"
    test_mode || execute_commands
  end
  
  def report
    rows = %w[added_files added_directories deleted_files deleted_directories existing_files].each do |name|
      files = self.send name.intern
      if files.any?
        puts name.capitalize.gsub(/_(\w)/) { " #{$1.upcase}" }
        puts '=' * name.to_s.length
        puts files.join(', ')
        puts
      end
    end
  end

protected
  def svn_command(args)
    cmd = [@options[:svn] || 'svn']
    if args =~ /^c(i|ommit)/
      cmd << "--username" << @options[:username] if @options[:username]
      cmd << "--password" << @options[:password] if @options[:password]
    end
    (cmd << args) * " "
  end
  
  def execute_commands
    Dir.chdir @destination do
      @commands.each do |c| 
        cmd = svn_command(c)
        puts "EXECUTING: #{cmd}" if @debug
        %x[#{cmd}] 
      end
    end
    nil
  end
  
  def process_path(path = nil)
    unless path.nil?
      dest_entry = @destination + path
      unless dest_entry.directory?
        return if ignore?(path.to_s)
        puts "ADDING DIR: #{path.inspect}" if @debug
        @added_directories << path.to_s
        return
      end
    end

    (path.nil? ? @source : @source + path).each_entry do |entry|
      next if entry.to_s =~ /^\.{1,2}$/
      full_entry   = path.nil? ? entry : path + entry
      next if ignore?(full_entry.to_s)
      source_entry = @source + full_entry
      if source_entry.directory?
        process_path(full_entry)
      elsif source_entry.file?
        process_file(full_entry)
      end
    end
  end
  
  def process_file(file)
    if (@destination + file).file?
      puts "EXISTING FILE: #{file.inspect}" if @debug
      @existing_files << file.to_s
    else
      puts "ADD FILE: #{file.inspect}" if @debug
      @added_files << file.to_s
    end
  end
  
  def ignore?(pathname)
    ignore_patterns.find { |p| p === pathname }
  end
end
