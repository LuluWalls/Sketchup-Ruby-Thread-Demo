require 'socket'
require 'cgi'
#require "objspace"

module Lulu
 
  module Sigint_Trap
    # WARNING - Do not blithely add a SIGINT handler to your ruby code, it is not safe. This code is for demo purposes only!!!
    # WARNING AGAIN- Do not blithely add a SIGINT handler to your ruby code, it is not safe. This code is for demo purposes only!!!
    # If you choose to ignore this warning other developers will find you. Signals can be re-entrant--that is, a signal handler
    # can be interrupted by another signal (or sometimes the same signal).
    #
    # Module Sigint_Trap is a SIGINT handler that interrupts in the main
    # thread (only when the thread is in the Ruby code). By default it will 'puts' an object
    # to the console or alternatively it will call a user supplied Proc.
    # further reading http://kirshatrov.com/2017/04/17/ruby-signal-trap/
    # also see self pipe https://gist.github.com/mvidner/bf12a0b3c662ca6a5784
    # and https://bugs.ruby-lang.org/issues/14222
    #
    # init()              sets up the SIGINT handler
    # add_message()       throws the SIGINT interrupt
    # 
    
    @pending_messages = []
    
    def self.init(time)
      @tt = time
      @old_signal_handler = Signal.trap("INT") do
        current_job = @pending_messages.shift
        if current_job
          print "%0.6f " % (Time.now - @tt).to_s
          if current_job.is_a?(Proc)
            current_job.call
          else
            puts current_job
          end
        else
          @old_signal_handler.call if @old_signal_handler.respond_to?(:call)
        end
      end #end of trap
      
      puts 'old SIGINT Handler' + @old_signal_handler.to_s
    end
    
    # if the web console is act ive then send them to the browser
    # otherwise, or if the messasge is a Proc object, interrupt the main thread via SIGINT
    def self.add_message(message)
      if Simple_server.connected? && !message.is_a?(Proc)
        #send to web console
        Simple_server.console_out(message)
      else
        # send to SIGINT trap
        @pending_messages << message
        Process.kill("INT", Process.pid)
      end
    end
  end #sigint_trap
 
  module Simple_server
    # A small webserver, call with http://localhost:2000/
    # This will obviously fail because of conflicting port numbers if you run it in two instances of sketchup
    @html_body = <<-EOF
      <!DOCTYPE html>
      <html><body><h2>HTML Forms</h2>
      <form action="simple_server">First name:<br>
      <input type="text" name="firstname" value="Mickey"><br>
      Last name:<br>
      <input type="text" name="lastname" value="Mouse"><br><br>
      <input type="submit" name="shut_down" value="Shut Down"><br><br>
      <input type="submit" name="shuttler_start" value="Start UI timer on main thread"> <input type="submit" name="shuttler_stop" value="Stop UI timer"><br><br>
      <input type="submit" name="tictoc_start" value="Start Background Thread"> <input type="submit" name="tictoc_stop" value="Stop Background Thread"></form> 
      </body></html>
    EOF
    @html_good = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nHello world! The time is "
    #@html_console_start = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nConsole Server Started "
    @html_console_start = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nConsole Server Started<script>function start_scroll_down(){scroll = setInterval(function(){ window.scrollBy(0, 1000); console.log('start');}, 1500);}start_scroll_down();</script> "
    @html_not_found = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"

    def self.server_start(time)
      @t = time
      @console_rd_pipe, @console_wr_pipe = IO.pipe
      @server = TCPServer.new('localhost', 2000)
      @server_thread = Thread.new {server_thread()}
      @server_thread.priority = 4
      @server_threads = []
      @console_connected 

    end
    
    def self.connected?()
      @console_connected 
    end
    
    def self.server_stop()
      begin
        @console_connected = nil
        @server_threads.each {|thr| thr.exit}
        #@console_thread.exit
        @server_thread.exit
        @server.close
        #
        @console_rd_pipe.close
        @console_wr_pipe.close
        
      rescue => e
        #send error messages from this thread to the ruby console
        Sigint_Trap.add_message("Exception in server stop: #{e.to_s}, #{e.backtrace.join("\n")}") 
      end #end begin
    end
    
    def self.console_out(message)
      @console_wr_pipe.puts "#{message}<br>" if @console_connected
    end
    
    def self.server_thread()
      begin
        loop do
          # I need to figure out how to close down these threads
          # or go back to a separate port for the console
          #
          # !!!!! this is causing problems because the Threads themselves are not wrapped in a begin rescue
          
          @server_threads << Thread.start(@server.accept) do |session|
            begin
              response = ''
              request = session.gets
              request_uri  = request.split(" ")[1]
              
              #send the request string to the stdout
              Sigint_Trap.add_message("TCPServer: #{request_uri}")
              
              if request_uri.start_with?('/favicon.ico')
                response << @html_not_found
                
              elsif request_uri.start_with?('/console')
                #this is the fdeed to the web console
                @console_connected = true
                @console_thread = Thread.current 
                session.print  "#{@html_console_start} #{Time.now.to_s}<br>Threads = #{@server_threads.size.to_s}<br>"
                loop do
                  #x = 10/0 #test exception handling
                  session.print @console_rd_pipe.gets
                end
                
              else
                params = request_uri.split("?")[1]
                params_hash = CGI::parse(request_uri.split("?")[1]) if params
                
                if params_hash
                  if params_hash["shuttler_start"][0]
                    #start a UI.timer from the main thread
                    proc = Proc.new {Lulu::start_shuttler()}
                    Sigint_Trap.add_message(proc)
                  end
                  if params_hash["shuttler_stop"][0]
                    proc = Proc.new {Lulu::stop_shuttler()}
                    Sigint_Trap.add_message(proc)
                  end
                  if params_hash["shut_down"][0]
                    proc = Proc.new {Lulu::stop_work()}
                    Sigint_Trap.add_message(proc)
                  end
                  if params_hash["tictoc_start"][0]
                    #start a thread from the server thread
                    Lulu::start_tictoc()
                  end
                  if params_hash["tictoc_stop"][0]
                   Lulu::stop_tictoc()
                  end
                end
                response << @html_good + Time.now.to_s
                response << @html_body
              end
                session.print response
                session.close
            rescue Errno::EPIPE
              Sigint_Trap.add_message('Errno::EPIPE client disconnected')
            retry # client has disconnected
            rescue => e
              #send error messages from this thread to the ruby console
              Sigint_Trap.add_message("Exception in server thread: #{e.to_s}, #{e.backtrace.join("\n")}") 
            end #end begin  
          end # do
        end # end loop
      rescue => e
        #send error messages from this thread to the ruby console
        Sigint_Trap.add_message("Exception in server process: #{e.to_s}, #{e.backtrace.join("\n")}") 
      end #end begin
    end #server_thread
  end #end simple server
  
  # Tic Toc
  # this thread will wake-up when we are executing ruby code
  # i.e. when not in a sketchup call and not in a C extension.
  def self.tictoc_thread()
    # careful, the value of @u, @v can change before it is used in SIGINT trap
    procA = Proc.new {puts "Timed Worker Proc A added at #{@u} called at #{Time.now - @t}"}
    procB = Proc.new {puts "Timed Worker Proc B added at #{@v} called at #{Time.now - @t}"}
    begin
      for i in 0...30
        sleep(0.5)
        #  SIGINT will not be triggered between these three add_message calls.
        #  Sigint_Trap.add_message("Timed worker tic    added at #{(Time.now - @t).to_s}")
        #  @u = Time.now - @t
        #  Sigint_Trap.add_message(procA)
        #  @v = Time.now - @t
        #  Sigint_Trap.add_message(procB)
        #x = 10/0 #force a Div0 exception
        
        Simple_server.console_out("hiccup")
        
      end 
    rescue => e
      #send error messages from this thread to the ruby console
      Sigint_Trap.add_message("#{e.to_s}, #{e.backtrace.join("\n")}")
    end
  end
  
  def self.start_tictoc()
    #puts 'start tictoc'
    Sigint_Trap.add_message("start tictoc")
    #Simple_server.console_out("start tictoc")
    if !@a || !@a.alive? 
      @a = Thread.new {tictoc_thread()}
      @a.priority = 4
    end
  end
  
  def self.stop_tictoc()
    Sigint_Trap.add_message("stop tictoc")
    #Simple_server.console_out("stop tictoc")
    @a.exit if @a.respond_to?(:exit)  #kill the demo worker thread
  end
  
  def self.start_work()
    puts 'Starting Services'
    Simple_server.server_start(@t)
  end
  
  def self.stop_work()
    puts 'Closing services'
    stop_tictoc()
    Simple_server.server_stop()
    puts 'server stopped'
  end
  
  # shuttler would be a bit of ruby code that polls for updates to the model
  def self.start_shuttler()
    Sigint_Trap.add_message("start shuttle")
    Simple_server.console_out("start shuttle")

    @shuttler = UI.start_timer(1.0,true) {puts "#{(Time.now - @t).to_s} shuttler called"}
  end
  
  def self.stop_shuttler()
    Sigint_Trap.add_message("stop shuttle")
    Simple_server.console_out("stop shuttle")
    UI.stop_timer(@shuttler) if @shuttler
    @shuttler = nil
    puts "#{(Time.now - @t).to_s} stop shuttler called"
  end
  
  ##################################################### 
  # initialize the sigint handler
  # start the server
  # WARNING - Do not blithely add a SIGINT handler to your ruby code, it is
  # not safe. This code is for demo purposes only!!!
  #####################################################
  @t = Time.now
  Sigint_Trap.init(@t)
  start_work()
  puts "Got here"
 
  #open a web app window
  link = "http://localhost:2000"
  system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  
  link = "http://localhost:2000/console"
  system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  #system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
  puts 'got there'
  
end


