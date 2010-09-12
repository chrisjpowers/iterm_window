# Developed March 17, 2008 by Chris Powers
#
# The ItermWindow class models an iTerm terminal window and allows for full control via Ruby commands.
# Under the hood, this class is a wrapper of iTerm's Applescript scripting API. Methods are used to
# generate Applescript code which is run as an <tt>osascript</tt> command when the ItermWindow initialization
# block is closed.
#
# ItermWindow::Tab models a tab (session) in an iTerm terminal window and allows for it to be controlled by Ruby.
# These tabs can be created with either the ItermWindow#open_bookmark method or the ItermWindow#open_tab
# method. Each tab is given a name (symbol) by which it can be accessed later as a method of ItermWindow.
#
# EXAMPLE - Open a new iTerm window, cd to a project and open it in TextMate
#
#   ItermWindow.open do
#     open_tab :my_tab do
#       write "cd ~/projects/my_project/trunk"
#       write "mate ./"
#     end
#   end
#
# EXAMPLE - Use the current iTerm window, cd to a project and open in TextMate, launch the server and the console and title them
#
#   ItermWindow.current do
#     open_tab :project_dir do
#       write "cd ~/projects/my_project/trunk"
#       write "mate ./"
#       set_title "MyProject Dir"
#     end
#
#     open_tab :server do
#       write "cd ~/projects/my_project/trunk"
#       write "script/server -p 3005"
#       set_title "MyProject Server"
#     end
#
#     open_tab :console do
#       write "cd ~/projects/my_project/trunk"
#       write "script/console"
#       set_title "MyProject Console"
#     end
#   end
#
# EXAMPLE - Same thing, but use bookmarks that were made for the server and console. Also, switch focus back to project dir.
#
#   ItermWindow.current do
#     open_tab :project_dir do
#       write "cd ~/projects/my_project/trunk"
#       write "mate ./"
#     end
#
#     open_bookmark :server, 'MyProject Server'
#     open_bookmark :console, 'MyProject Console'
#
#     project_dir.select
#   end
#
# EXAMPLE - Arbitrarily open two tabs, switch between them and run methods/blocks with Tab#select method and Tab#write directly
#
#   ItermWindow.open do
#     open_tab :first_tab
#     open_tab :second_tab
#     first_tab.select do
#       write 'cd ~/projects'
#       write 'ls'
#     end
#     second_tab.write "echo 'hello there!'"
#     first_tab.select # brings first tab back to focus
#   end


# The ItermWindow class models an iTerm terminal window and allows for full control via Ruby commands.
class ItermWindow

  # While you can directly use ItermWindow.new, using either ItermWindow.open or
  # ItermWindow.current is the preferred method.
  def initialize
    @buffer = []
    @tabs = {}
  end

  # Creates a new terminal window, runs the block on it
  def self.open(&block)
    self.new.run(:new, &block)
  end

  # Selects the first terminal window, runs the block on it
  def self.current(&block)
    self.new.run(:current, &block)
  end

  def run(window_type = :new, &block)
    run_commands window_type, &block
    send_output
  end

  # Creates a new tab from a bookmark, runs the block on it
  def open_bookmark(name, bookmark, &block)
    create_tab(name, bookmark, &block)
  end

  # Creates a new tab from 'Default Session', runs the block on it
  def open_tab(name, &block)
    create_tab(name, 'Default Session', &block)
  end

  # Outputs a single line of Applescript code
  def output(command)
    @buffer << command.gsub(/'/, '"')
  end


  private

  # Outputs @buffer to the command line as an osascript function
  def send_output
    buffer_str = @buffer.map {|line| "-e '#{line}'"}.join(' ')
    shell_out "osascript #{buffer_str}"
  end

  # Initializes the terminal window
  def run_commands(window_type, &block)
    window_types = {:new => '(make new terminal)', :current => 'first terminal'}
    raise ArgumentError, "ItermWindow#run_commands should be passed :new or :current." unless window_types.keys.include? window_type
    output "tell application 'iTerm'"
    output "activate"
    output "set myterm to #{window_types[window_type]}"
    output "tell myterm"
    self.instance_eval(&block) if block_given?
    output "end tell"
    output "end tell"
  end

  # Creates a new Tab object, either default or from a bookmark,
  # and creates a convenience method for retrieval
  def create_tab(name, bookmark=nil, &block)
    @tabs[name] = Tab.new(self, name, bookmark, &block)
    create_tab_convenience_method(name)
  end

  private

  def create_tab_convenience_method(name)
    (class << self; self; end).send(:define_method, name) do
      @tabs[name]
    end
  end

  def shell_out(str)
    %x{str}
  end


  # The Tab class models a tab (session) in an iTerm terminal window and allows for it to be controlled by Ruby.
  class Tab

    attr_reader :name
    attr_reader :bookmark

    def initialize(window, name, bookmark = nil, &block)
      @name = name
      @bookmark = bookmark
      @window = window
      @currently_executing_block = false
      output "launch session '#{@bookmark}'"
      # store tty id for later access
      output "set #{name}_tty to the tty of the last session"
      execute_block &block if block_given?
    end

    # Brings a tab into focus, runs a block on it if passed
    def select(&block)
      if block_given?
        execute_block &block
      else
        output "select session id #{name}_tty"
      end
    end

    # Writes a command into the terminal tab
    def write(command)
      if @currently_executing_block
        output "write text '#{command}'"
      else
        execute_block { write command }
      end
    end

    # Sets the title of the tab (ie the text on the iTerm tab itself)
    def set_title(str)
      if @currently_executing_block
        output "set name to '#{str}'"
      else
        execute_block { set_title = str }
      end
    end

    # Runs a block on this tab with proper opening and closing statements
    def execute_block(&block)
      @currently_executing_block = true
      output "tell session id #{name}_tty"
      self.instance_eval(&block)
      output "end tell"
      @currently_executing_block = false
    end

    private

    def output(command)
      @window.output command
    end


  end

end