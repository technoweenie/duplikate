require 'pathname'
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
  def self.process(source, dest)
    dupe = new(source, dest)
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
  def self.execute(message, source, dest)
    dupe = new(source, dest)
    dupe.execute(message)
    dupe
  end

  def initialize(source, dest, is_inverse=false)
    @source, @destination = Pathname.new(source), Pathname.new(dest)
    @inverse = self.class.new(dest, source, true) unless is_inverse
  end
  
  def process
    @deleted_files, @deleted_directories, @added_files, @added_directories, @existing_files = [], [], [], [], []
    if @inverse
      @inverse.process
      @deleted_files       = @inverse.added_files
      @deleted_directories = @inverse.added_directories
    end
    process_path
  end
  
  def execute(message, test_mode = false)
    process if @existing_files.nil?
    @commands = []
    (@added_files + @added_directories).each do |added|
      @commands << "add #{added}"
    end
    (@deleted_files + @deleted_directories).each do |deleted|
      @commands << "rm #{deleted}"
    end
    @commands << "ci -m '#{message}'"
    if test_mode
      true
    else
      @commands.each { |c| %x[svn #{c}] }
    end
  end

protected
  def process_path(path = nil)
    unless path.nil?
      dest_entry = @destination + path
      unless dest_entry.directory?
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
    ((@destination + file).file? ? @existing_files : @added_files) << file.to_s
  end
end