require 'spec_helper'

describe ItermWindow do
  before(:each) do
    @window = ItermWindow.new
  end
  
  describe ".current" do
    it "should instantiate the current window and run the block" do
      ItermWindow.should_receive(:new).and_return(@window)
      @window.should_receive(:run).with(:current)
      ItermWindow.current do
        
      end
    end
  end
  
  describe ".open" do
    it "should instantiate a new window and run the block" do
      ItermWindow.should_receive(:new).and_return(@window)
      @window.should_receive(:run).with(:new)
      ItermWindow.open do
        
      end
    end
  end
  
  describe "opening a tab (example 1)" do
    before(:each) do
      ItermWindow.should_receive(:new).and_return(@window)
    end
    
    it "should generate and run the right Applescript" do
      desired = "osascript -e 'tell application \"iTerm\"' -e 'activate' -e 'set myterm to (make new terminal)' -e 'tell myterm' -e 'launch session \"Default Session\"' -e 'set my_tab_tty to the tty of the last session' -e 'tell session id my_tab_tty' -e 'write text \"cd ~/projects/my_project/trunk\"' -e 'write text \"mate ./\"' -e 'end tell' -e 'end tell' -e 'end tell'"
      @window.should_receive(:shell_out).with(desired)
      
      ItermWindow.open do
        open_tab :my_tab do
          write "cd ~/projects/my_project/trunk"
          write "mate ./"
        end
      end
    end
  end
  
  describe "open multiple tabs (example 2)" do
    before(:each) do
      ItermWindow.should_receive(:new).and_return(@window)
    end
    
    it "should generate and run the right Applescript" do
      desired = "osascript -e 'tell application \"iTerm\"' -e 'activate' -e 'set myterm to first terminal' -e 'tell myterm' -e 'launch session \"Default Session\"' -e 'set project_dir_tty to the tty of the last session' -e 'tell session id project_dir_tty' -e 'write text \"cd ~/projects/my_project/trunk\"' -e 'write text \"mate ./\"' -e 'set name to \"MyProject Dir\"' -e 'end tell' -e 'launch session \"Default Session\"' -e 'set server_tty to the tty of the last session' -e 'tell session id server_tty' -e 'write text \"cd ~/projects/my_project/trunk\"' -e 'write text \"script/server -p 3005\"' -e 'set name to \"MyProject Server\"' -e 'end tell' -e 'launch session \"Default Session\"' -e 'set console_tty to the tty of the last session' -e 'tell session id console_tty' -e 'write text \"cd ~/projects/my_project/trunk\"' -e 'write text \"script/console\"' -e 'set name to \"MyProject Console\"' -e 'end tell' -e 'end tell' -e 'end tell'"
      @window.should_receive(:shell_out).with(desired)
      
      ItermWindow.current do
        open_tab :project_dir do
          write "cd ~/projects/my_project/trunk"
          write "mate ./"
          set_title "MyProject Dir"
        end
    
        open_tab :server do
          write "cd ~/projects/my_project/trunk"
          write "script/server -p 3005"
          set_title "MyProject Server"
        end
        
        open_tab :console do
          write "cd ~/projects/my_project/trunk"
          write "script/console"
          set_title "MyProject Console"
        end
      end
    end
  end
  
  describe "open tabs using bookmarks (example 3)" do
    before(:each) do
      ItermWindow.should_receive(:new).and_return(@window)
    end
    
    it "should generate and run the correct Applescript" do
      desired = "osascript -e 'tell application \"iTerm\"' -e 'activate' -e 'set myterm to first terminal' -e 'tell myterm' -e 'launch session \"Default Session\"' -e 'set project_dir_tty to the tty of the last session' -e 'tell session id project_dir_tty' -e 'write text \"cd ~/projects/my_project/trunk\"' -e 'write text \"mate ./\"' -e 'end tell' -e 'launch session \"MyProject Server\"' -e 'set server_tty to the tty of the last session' -e 'launch session \"MyProject Console\"' -e 'set console_tty to the tty of the last session' -e 'select session id project_dir_tty' -e 'end tell' -e 'end tell'"
      @window.should_receive(:shell_out).with(desired)
      
      ItermWindow.current do
        open_tab :project_dir do
          write "cd ~/projects/my_project/trunk"
          write "mate ./"
        end
    
        open_bookmark :server, 'MyProject Server'
        open_bookmark :console, 'MyProject Console'
    
        project_dir.select
      end
    end
  end
  
  describe "switching between tabs (example 4)" do
    before(:each) do
      ItermWindow.should_receive(:new).and_return(@window)
    end
    
    it "should generate and run the correct Applescript" do
      desired = "osascript -e 'tell application \"iTerm\"' -e 'activate' -e 'set myterm to (make new terminal)' -e 'tell myterm' -e 'launch session \"Default Session\"' -e 'set first_tab_tty to the tty of the last session' -e 'launch session \"Default Session\"' -e 'set second_tab_tty to the tty of the last session' -e 'tell session id first_tab_tty' -e 'write text \"cd ~/projects\"' -e 'write text \"ls\"' -e 'end tell' -e 'tell session id second_tab_tty' -e 'write text \"echo \"hello there!\"\"' -e 'end tell' -e 'select session id first_tab_tty' -e 'end tell' -e 'end tell'"
      @window.should_receive(:shell_out).with(desired)
      
      ItermWindow.open do
        open_tab :first_tab
        open_tab :second_tab
        first_tab.select do
          write 'cd ~/projects'
          write 'ls'
        end
        second_tab.write "echo 'hello there!'"
        first_tab.select
      end
    end
  end
end
