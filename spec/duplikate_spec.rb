require File.join(File.dirname(__FILE__), 'spec_helper')

describe Duplikate do
  before do
    @source    = File.join(File.dirname(__FILE__), 'source')
    @dest      = File.join(File.dirname(__FILE__), 'dest')
    @duplikate = Duplikate.new @source, @dest
    @duplikate.process
  end
  
  it "gets #source location as Pathname" do
    @duplikate.source.should == Pathname.new(@source)
  end
  
  it "gets #destination location as Pathname" do
    @duplikate.destination.should == Pathname.new(@dest)
  end
  
  it "processes added_directories" do
    @duplikate.should have(1).added_directories
    @duplikate.added_directories.should include("foo/addme")
  end
  
  it "processes added_files" do
    @duplikate.should have(1).added_files
    @duplikate.added_files.should include("addme.txt")
  end
  
  it "processes existing_files" do
    @duplikate.should have(3).existing_files
    @duplikate.existing_files.should include("same.txt")
    @duplikate.existing_files.should include("foo/same.txt")
    @duplikate.existing_files.should include("foo/same/changed.txt")
  end
  
  it "processes deleted_directories" do
    @duplikate.should have(2).deleted_directories
    @duplikate.deleted_directories.should include("deleteme")
    @duplikate.deleted_directories.should include("foo/deleteme")
  end
  
  it "processes deleted_files" do
    @duplikate.should have(1).deleted_files
    @duplikate.deleted_files.should include("deleteme.txt")
  end
  
  it "executes svn commands" do
    @duplikate.execute("running spec", true)
    @duplikate.should have(6).commands
    @duplikate.commands.should include("add addme.txt")
    @duplikate.commands.should include("add foo/addme")
    @duplikate.commands.should include("rm deleteme.txt")
    @duplikate.commands.should include("rm deleteme")
    @duplikate.commands.should include("rm foo/deleteme")
    @duplikate.commands.should include("ci -m 'running spec'")
  end
  
  describe :report do
    it "prints changes" do
      text = capturing_stdout { @duplikate.report }
      text.should =~ /Added Files\n=+\naddme.txt/
      text.should =~ /Added Directories\n=+\nfoo\/addme/
      text.should =~ /Deleted Files\n=+\ndeleteme.txt/
      text.should =~ /Deleted Directories\n=+\ndeleteme/
    end
  end
  
  describe :dry_run do
    it "prints commands" do
      lines = capturing_stdout { @duplikate.dry_run }.split("\n")
      lines.length.should == 6
      lines.should include("add addme.txt")
      lines.should include("add foo/addme")
      lines.should include("rm deleteme.txt")
      lines.should include("rm deleteme")
      lines.should include("rm foo/deleteme")
      lines.should include("ci -m '<commit message>'")
    end
  end
end

describe Duplikate, "ignore" do
  before do
    @source    = File.join(File.dirname(__FILE__), 'source')
    @dest      = File.join(File.dirname(__FILE__), 'dest')
    @duplikate = Duplikate.new @source, @dest
  end

  it "omits ignored files" do
    @duplikate.ignore 'addme.txt'
    @duplikate.process
    @duplikate.added_files.should_not include("addme.txt")
  end
  
  it "omits ignored directories" do
    @duplikate.ignore 'foo/addme'
    @duplikate.process
    @duplikate.added_directories.should_not include("foo/addme")
  end
  
  it "omits ignored file patterns" do
    @duplikate.ignore /ad*me/
    @duplikate.process
    @duplikate.added_directories.should_not include("foo/addme")
    @duplikate.added_files.should_not include("addme.txt")
  end
end

describe Duplikate, "syncing two directories" do
  before do
    @source    = File.join(File.dirname(__FILE__), 'source')
    @dest      = File.join(File.dirname(__FILE__), 'dest')
    FileUtils.rm_rf @source + '-copy'
    FileUtils.rm_rf @dest   + '-copy'
    FileUtils.cp_r @source, @source + '-copy'
    FileUtils.cp_r @dest,   @dest   + '-copy'
    @source = Pathname.new(@source + '-copy')
    @dest   = Pathname.new(@dest   + '-copy')
    @duplikate = Duplikate.new @source, @dest
    def @duplikate.execute_commands() end
    @duplikate.execute("running spec")
  end
  
  it "creates added directories" do
    (@dest + 'foo/addme').should be_directory
  end
  
  it "creates added files" do
    (@dest + 'addme.txt').should be_file
  end
  
  it "deletes deleted directories" do
    (@dest + 'deleteme').should_not be_directory
    (@dest + 'foo/deleteme').should_not be_directory
  end
  
  it "deletes deleted files" do
    (@dest + 'deleteme.txt').should_not be_file
  end
  
  it "updates changed files" do
    file = 'foo/same/changed.txt'
    IO.read(@source + file).should == IO.read(@dest + file)
  end
end
