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
end