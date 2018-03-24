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
    
    def self.add_message(message)
      @pending_messages << message
      # trigger the SIGINT
      Process.kill("INT", Process.pid)
    end
  end #sigint trap
 
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
      <input type="submit" name="shuttler_start" value="Start Shuttler"> <input type="submit" name="shuttler_stop" value="Stop Shuttler"><br><br>
      <input type="submit" name="tictoc_start" value="Start Tictoc Thread"> <input type="submit" name="tictoc_stop" value="Stop Tictoc Thread"></form> 
      </body></html>
    EOF
    @html_good = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nHello world! The time is "
    @html_not_found = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"

    def self.server_start(time)
      @t = time
      @server = TCPServer.new('localhost', 2000)
      @thread = Thread.new {server_thread()}
      @thread.priority = 4
    end
    
    def self.server_stop()
      @thread.exit
      @server.close
    end
    
    def self.server_thread()
      begin
        loop do
            session = @server.accept 
            response = ''
            request = session.gets
            request_uri  = request.split(" ")[1]
            
            #send the request string to the stdout
            Sigint_Trap.add_message("TCPServer: #{request_uri}")
            
            if request_uri.start_with?('/favicon.ico')
              response << @html_not_found
            else
              params = request_uri.split("?")[1]
              params_hash = CGI::parse(request_uri.split("?")[1]) if params
              
              if params_hash
                if params_hash["shuttler_start"][0]
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
                if params_hash["tictoc_start"][0] #does this new thread need to be started by main?
                  proc = Proc.new {Lulu::start_tictoc()}
                  Sigint_Trap.add_message(proc)
                end
                if params_hash["tictoc_stop"][0]
                  proc = Proc.new {Lulu::stop_tictoc()}
                  Sigint_Trap.add_message(proc)
                end
              end
              
              response << @html_good + Time.now.to_s
              response << @html_body
            end
              session.print response
              session.close
        end
      rescue Errno::EPIPE
        Sigint_Trap.add_message('client disconnected')
        retry # client has disconnected
      rescue => e
        #send error messages from this thread to the ruby console
        Sigint_Trap.add_message("#{e.to_s}, #{e.backtrace.join("\n")}") 
      end
    end
  end #end simple server
  
  # Tic Toc
  # this thread will wake-up when we are executing ruby code
  # i.e. when not in a sketchup call and not in a C extension.
  def self.worker1()
    # careful, the value of @u, @v can change before it is used in SIGINT trap
    procA = Proc.new {puts "Timed Worker Proc A added at #{@u} called at #{Time.now - @t}"}
    procB = Proc.new {puts "Timed Worker Proc B added at #{@v} called at #{Time.now - @t}"}
    begin
      for i in 0...30
        sleep(0.5)
        #SIGINT will not be triggered between these three add_message calls.
        Sigint_Trap.add_message("Timed worker tic    added at #{(Time.now - @t).to_s}")
        @u = Time.now - @t
        Sigint_Trap.add_message(procA)
        @v = Time.now - @t
        Sigint_Trap.add_message(procB)
        #@v = 0.0 # 
        #x = 10/0 #force a Div0 exception
      end 
    rescue => e
      #send error messages from this thread to the ruby console
      Sigint_Trap.add_message("#{e.to_s}, #{e.backtrace.join("\n")}")
    end
  end
  
  def self.start_tictoc()
    puts 'start tictoc'
    puts @a.inspect
    if !@a || !@a.alive? 
      @a = Thread.new {worker1()}
      @a.priority = 4
    end
  end
  
  def self.stop_tictoc()
    puts 'stop tictoc'
    @a.exit if @a.respond_to?(:exit)  #kill the demo worker thread
  end
  
  def self.start_work()
    puts 'Starting Srcvices'
    #start_tictoc()
    Simple_server.server_start(@t)
  end
  
  def self.stop_work()
    puts 'Closing services'
    stop_tictoc()
    Simple_server.server_stop()
    puts 'server stopped'
  end
  
  # shuttler would be a bit of ruby code polling for updates to the model
  def self.start_shuttler()
    @shuttler = UI.start_timer(1.0,true) {puts "#{(Time.now - @t).to_s} shuttler called"}
  end
  
  def self.stop_shuttler()
    UI.stop_timer(@shuttler) if @shuttler
    @shuttler = nil
    puts "#{(Time.now - @t).to_s}  stop shuttler called"
  end
  
  ##################################################### 
  # initialize the sigint handler after load
  # start demo worker thread and server
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
  #system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
  puts 'got there'
  
  # sleep and then execute a several second loop in the main thread
  # this will hang the console but the threads will continue to run

  # start a timer that will not be triggered until we return from this module
  # tim = UI.start_timer(0,false) {puts "#{(Time.now - @t).to_s}  UI stop_timer called"}

  # sleep(5.0)
  # puts "#{(Time.now - @t).to_s} ==== starting loop"
  # x = 0
  # until x == 100000000
   # x += 1
  # end
  # puts "#{(Time.now - @t).to_s} ==== end loop"
  # sleep (5.0)
  
# ###  stop_work()
  # puts "#{(Time.now - @t).to_s} end module load"

end
