require 'spec_helper'

describe Dragonfly::TempObject do

  ####### Helper Methods #######

  def sample_path(filename)
    File.join(SAMPLES_DIR, filename)
  end

  def new_tempfile(data='HELLO')
    tempfile = Tempfile.new('test')
    tempfile.write(data)
    tempfile.rewind
    tempfile
  end

  def new_file(data='HELLO', path="/tmp/test_file")
    File.open(path, 'w') do |f|
      f.write(data)
    end
    File.new(path)
  end

  def new_pathname(data='HELLO', path="/tmp/test_file")
    File.open(path, 'w') do |f|
      f.write(data)
    end
    Pathname.new(path)
  end

  def new_temp_object(data, klass=Dragonfly::TempObject)
    klass.new(initialization_object(data))
  end

  def initialization_object(data)
    raise NotImplementedError, "This should be implemented in the describe block!"
  end

  def get_parts(temp_object)
    parts = []
    temp_object.each do |bytes|
      parts << bytes
    end
    parts.length.should >= 2 # Sanity check to check that the sample file is adequate for this test
    parts
  end

  ###############################

  it "should raise an error if initialized with a non-string/file/tempfile" do
    lambda{
      Dragonfly::TempObject.new(3)
    }.should raise_error(ArgumentError)
  end

  shared_examples_for "common behaviour" do

    describe "simple initialization" do

      before(:each) do
        @temp_object = new_temp_object('HELLO')
      end

      describe "data" do
        it "should return the data correctly" do
          @temp_object.data.should == 'HELLO'
        end
      end

      describe "file" do
        it "should return a readable file" do
          @temp_object.file.should be_a(File)
        end
        it "should contain the correct data" do
          @temp_object.file.read.should == 'HELLO'
        end
        it "should yield a file then close it if a block is given" do
          @temp_object.file do |f|
            f.read.should == 'HELLO'
            f.should_receive :close
          end
        end
        it "should return whatever is returned from the block if a block is given" do
          @temp_object.file do |f|
            'doogie'
          end.should == 'doogie'
        end
        it "should enable reading the file twice" do
          @temp_object.file{|f| f.read }.should == "HELLO"
          @temp_object.file{|f| f.read }.should == "HELLO"
        end
      end

      describe "tempfile" do
        it "should create a closed tempfile" do
          @temp_object.tempfile.should be_a(Tempfile)
          @temp_object.tempfile.should be_closed
        end
        it "should contain the correct data" do
          @temp_object.tempfile.open.read.should == 'HELLO'
        end
      end

      describe "path" do
        it "should return an absolute file path" do
          @temp_object.path.should =~ %r{^/\w+}
        end
      end

      describe "size" do
        it "should return the size in bytes" do
          @temp_object.size.should == 5
        end
      end

      describe "to_file" do
        before(:each) do
          @filename = 'eggnog.txt'
          FileUtils.rm(@filename) if File.exists?(@filename)
        end
        after(:each) do
          FileUtils.rm(@filename) if File.exists?(@filename)
        end
        it "should write to a file" do
          @temp_object.to_file(@filename)
          File.exists?(@filename).should be_true
        end
        it "should write the correct data to the file" do
          @temp_object.to_file(@filename)
          File.read(@filename).should == 'HELLO'
        end
        it "should return a readable file" do
          file = @temp_object.to_file(@filename)
          file.should be_a(File)
          file.read.should == 'HELLO'
        end
        it "should have 644 permissions" do
          @temp_object.to_file(@filename)
          File::Stat.new(@filename).mode.to_s(8).should =~ /644$/
        end
      end

    end

    describe "each" do
      it "should yield 8192 bytes each time" do
        temp_object = new_temp_object(File.read(sample_path('round.gif')))
        parts = get_parts(temp_object)
        parts[0...-1].each do |part|
          part.bytesize.should == 8192
        end
        parts.last.bytesize.should <= 8192
      end
      it "should yield the number of bytes specified in the class configuration" do
        klass = Class.new(Dragonfly::TempObject)
        temp_object = new_temp_object(File.read(sample_path('round.gif')), klass)
        klass.block_size = 3001
        parts = get_parts(temp_object)
        parts[0...-1].each do |part|
          part.length.should == 3001
        end
        parts.last.length.should <= 3001
      end
    end
    
    describe "closing" do
      before(:each) do
        @temp_object = new_temp_object("wassup")
      end
      it "should delete its tempfile" do
        tempfile = @temp_object.tempfile
        path = tempfile.path
        path.should_not be_empty
        @temp_object.close
        File.exist?(path).should be_false
      end
      %w(tempfile file data).each do |method|
        it "should raise error when calling #{method}" do
          @temp_object.close
          expect{
            @temp_object.send(method)
          }.to raise_error(Dragonfly::TempObject::Closed)
        end
      end
      it "should not report itself as closed to begin with" do
        @temp_object.should_not be_closed
      end
      it "should report itself as closed after closing" do
        @temp_object.close
        @temp_object.should be_closed
      end
    end

  end

  describe "initializing from a string" do

    def initialization_object(data)
      data
    end

    it_should_behave_like "common behaviour"

    it "should not create a file when calling each" do
      temp_object = new_temp_object('HELLO')
      temp_object.should_not_receive(:tempfile)
      temp_object.each{}
    end
  end

  describe "initializing from a tempfile" do

    def initialization_object(data)
      new_tempfile(data)
    end

    it_should_behave_like "common behaviour"

    it "should not create a data string when calling each" do
      temp_object = new_temp_object('HELLO')
      temp_object.should_not_receive(:data)
      temp_object.each{}
    end

    it "should return the tempfile's path" do
      temp_object = new_temp_object('HELLO')
      temp_object.path.should == temp_object.tempfile.path
    end
  end

  describe "initializing from a file" do

    def initialization_object(data)
      new_file(data)
    end

    it_should_behave_like "common behaviour"

    it "should not create a data string when calling each" do
      temp_object = new_temp_object('HELLO')
      temp_object.should_not_receive(:data)
      temp_object.each{}
    end

    it "should return the file's path" do
      file = new_file('HELLO')
      temp_object = Dragonfly::TempObject.new(file)
      temp_object.path.should == file.path
    end
    
    it "should return an absolute path even if the file wasn't instantiated like that" do
      file = new_file('HELLO', 'testfile')
      temp_object = Dragonfly::TempObject.new(file)
      temp_object.path.should =~ %r{^/\w.*testfile}
      file.close
      FileUtils.rm(file.path)
    end
  end

  describe "initializing from a pathname" do

    def initialization_object(data)
      new_pathname(data)
    end

    it_should_behave_like "common behaviour"

    it "should not create a data string when calling each" do
      temp_object = new_temp_object('HELLO')
      temp_object.should_not_receive(:data)
      temp_object.each{}
    end

    it "should return the file's path" do
      pathname = new_pathname('HELLO')
      temp_object = Dragonfly::TempObject.new(pathname)
      temp_object.path.should == pathname.to_s
    end
    
    it "should return an absolute path even if the pathname is relative" do
      pathname = new_pathname('HELLO', 'testfile')
      temp_object = Dragonfly::TempObject.new(pathname)
      temp_object.path.should =~ %r{^/\w.*testfile}
      pathname.delete
    end
  end

  describe "initializing from another temp object" do
    
    def initialization_object(data)
      Dragonfly::TempObject.new(data)
    end
    
    before(:each) do
      @temp_object1 = Dragonfly::TempObject.new(new_tempfile('hello'))
      @temp_object2 = Dragonfly::TempObject.new(@temp_object1)
    end
    
    it_should_behave_like "common behaviour"
    
    it "should not be the same object" do
      @temp_object1.should_not == @temp_object2
    end
    it "should have the same data" do
      @temp_object1.data.should == @temp_object2.data
    end
    it "should have the same file path" do
      @temp_object1.path.should == @temp_object2.path
    end
  end

  describe "original_filename" do
    before(:each) do
      @obj = new_tempfile
    end
    it "should set the original_filename if the initial object responds to 'original filename'" do
      def @obj.original_filename
        'jimmy.page'
      end
      Dragonfly::TempObject.new(@obj).original_filename.should == 'jimmy.page'
    end
    it "should not set the name if the initial object doesn't respond to 'original filename'" do
      Dragonfly::TempObject.new(@obj).original_filename.should be_nil
    end
    it "should set the name if the initial object is a file object" do
      file = File.new(SAMPLES_DIR + '/round.gif')
      temp_object = Dragonfly::TempObject.new(file)
      temp_object.original_filename.should == 'round.gif'
    end
    it "should set the name if the initial object is a pathname" do
      pathname = Pathname.new(SAMPLES_DIR + '/round.gif')
      temp_object = Dragonfly::TempObject.new(pathname)
      temp_object.original_filename.should == 'round.gif'
    end
  end

end
