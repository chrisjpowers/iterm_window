# Developed March 17, 2008 by Chris Powers, Killswitch Collective http://killswitchcollective.com
# 
# The ItermWindow class models an iTerm terminal window and allows for full control via Ruby commands.
# Under the hood, this class is a wrapper of iTerm's Applescript scripting API. Methods are used to
# generate Applescript code which is run as an <tt>osascript</tt> command when the ItermWindow initialization
# block is closed.
# 
# ItermWindow::Tab models a tab (session) in an iTerm terminal window and allows for it to be controlled by Ruby.
# These tabs can be created with either the ItermWindow#open_bookmark method or the ItermWindow#open_tab
# method. Each tab is given a name (symbol) by which it can be accessed later in the code using
# the ItermWindow's bracket method (ie window[:tab_name]).
# 
# EXAMPLE - Open a new iTerm window, cd to a project and open it in TextMate
# 
#   ItermWindow.open do |window|
#     window.open_tab :my_tab do |tab|
#       tab.write "cd ~/projects/my_project/trunk"
#       tab.write "mate ./"
#     end
#   end
# 
# EXAMPLE - Use the current iTerm window, cd to a project and open in TextMate, launch the server and the console and title them
# 
#   ItermWindow.current do |window|
#     window.open_tab :project_dir do |tab|
#       tab.write "cd ~/projects/my_project/trunk"
#       tab.write "mate ./"
#       tab.title = "MyProject Dir"
#     end
#     window.open_tab :server do |tab|
#       tab.write "cd ~/projects/my_project/trunk"
#       tab.write "script/server -p 3005"
#       tab.title = "MyProject Server"
#     end
#     window.open_tab :console do |tab|
#       tab.write "cd ~/projects/my_project/trunk"
#       tab.write "script/console"
#       tab.title = "MyProject Console"
#     end
#   end
#
# EXAMPLE - Same thing, but use bookmarks that were made for the server and console. Also, switch focus back to project dir.
# 
#   ItermWindow.current do |window|
#     window.open_tab :project_dir do |tab|
#       tab.write "cd ~/projects/my_project/trunk"
#       tab.write "mate ./"
#     end
#     window.open_bookmark :server, 'MyProject Server'
#     window.open_bookmark :console, 'MyProject Console'
#     window[:project_dir].select
# 
# EXAMPLE - Arbitrarily open two tabs, switch between them and run methods/blocks with Tab#select method and Tab#write directly
# 
#   ItermWindow.open do |window|
#     window.open_tab :first_tab
#     window.open_tab :second_tab
#     window[:first_tab].select do |tab|
#       tab.write 'cd ~/projects'
#       tab.write 'ls'
#     end
#     window[:second_tab].write "echo 'hello there!'"
#     window[:first_tab].select # brings first tab back to focus
#   end


# The ItermWindow class models an iTerm terminal window and allows for full control via Ruby commands.
class ItermWindow
  
  # While you can directly use ItermWindow.new, using either ItermWindow.open or 
  # ItermWindow.current is the preferred method.
  def initialize(window_type = :new, &block)
    @buffer = []
    @tabs = {}
    run_commands window_type, &block
    send_output
  end
  
  # Creates a new terminal window, runs the block on it
  def self.open(&block)
    new(:new, &block)
  end
  
  # Selects the first terminal window, runs the block on it
  def self.current(&block)
    new(:current, &block)
  end
  
  # Directly accesses a tab by its name
  def [](tab_name)
    @tabs[tab_name]
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
    `osascript #{buffer_str}`
    # puts buffer_str
  end
  
  # Initializes the terminal window
  def run_commands(window_type)
    window_types = {:new => '(make new terminal)', :current => 'first terminal'}
    raise ArgumentError, "ItermWindow#run_commands should be passed :new or :current." unless window_types.keys.include? window_type
    output "tell application 'iTerm'"
    output "activate"
    output "set myterm to #{window_types[window_type]}"
    output "tell myterm"
    yield self if block_given?
    output "end tell"
    output "end tell"
  end
  
  # Creates a new Tab object, either default or from a bookmark
  def create_tab(name, bookmark=nil, &block)
    @tabs[name] = Tab.new(self, name, bookmark, &block)
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
        execute_block { |tab| tab.write command }
      end
    end
    
    # Sets the title of the tab (ie the text on the iTerm tab itself)
    def title=(str)
      if @currently_executing_block
        output "set name to '#{str}'"
      else
        execute_block { |tab| tab.title = str }
      end
    end
    
    # These style methods keep crashing iTerm for some reason...
    
    # # Sets the tab's font color
    # def font_color=(str)
    #   if @currently_executing_block
    #     output "set foreground color to '#{str}'"
    #   else
    #     execute_block { |tab| tab.font_color = str }
    #   end
    # end
    # 
    # # Sets the tab's background color
    # def background_color=(str)
    #   if @currently_executing_block
    #     output "set background color to '#{str}'"
    #   else
    #     execute_block { |tab| tab.bg_color = str }
    #   end
    # end
    # alias_method :bg_color=, :background_color=
    # 
    # # Sets the tab's transparency
    # def transparency=(float)
    #   if @currently_executing_block
    #     output "set transparency to '#{float}'"
    #   else
    #     execute_block { |tab| tab.transparency = float }
    #   end
    # end
    
    # Runs a block on this tab with proper opening and closing statements
    def execute_block
      @currently_executing_block = true
      output "tell session id #{name}_tty"
      yield self
      output "end tell"
      @currently_executing_block = false
    end
    
    private
          
    def output(command)
      @window.output command
    end

    
  end
  
end