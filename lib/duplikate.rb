require 'pathname'
require 'fileutils'
class Duplikate
  attr_accessor :source, :destination
  attr_reader :deleted_files, :deleted_directories, :added_files, :added_directories, :existing_files, :commands

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

  def initialize(source, dest, options = nil)
    @options = options || {}
    @debug   = @options[:debug]
    @source, @destination = Pathname.new(source), Pathname.new(dest)
    @inverse = self.class.new(dest, source, @options.merge(:is_inverse => true)) unless @options[:is_inverse]
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
        puts "ADDING DIR: #{path.inspect}" if @debug
        @added_directories << path.to_s
        return
      end
    end

    (path.nil? ? @source : @source + path).each_entry do |entry|
      next if entry.to_s =~ /^\.(git|svn)?\.?$/
      full_entry   = path.nil? ? entry : path + entry
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
end