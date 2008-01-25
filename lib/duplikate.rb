require 'pathname'
class Duplikate
  attr_accessor :source, :destination
  attr_reader :deleted_files, :deleted_directories, :added_files, :added_directories, :existing_files

  def initialize(source, dest, is_inverse=false)
    @source, @destination = Pathname.new(source), Pathname.new(dest)
    @inverse = self.class.new(dest, source, true) unless is_inverse
  end
  
  def process(&block)
    @deleted_files, @deleted_directories, @added_files, @added_directories, @existing_files = [], [], [], [], []
    if @inverse
      @inverse.process
      @deleted_files       = @inverse.added_files
      @deleted_directories = @inverse.added_directories
    end
    process_path(&block)
  end

protected
  def process_path(path = nil, &block)
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
        process_path(full_entry, &block)
      elsif source_entry.file?
        process_file(full_entry, &block)
      end
    end
  end
  
  def process_file(file, &block)
    if (@destination + file).file?
      if block
        block.call file.to_s
      else
        @existing_files << file.to_s
      end
    else
      @added_files << file.to_s
    end
  end
end