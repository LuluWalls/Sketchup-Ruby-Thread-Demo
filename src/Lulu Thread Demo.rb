require 'socket'
require "objspace"

module Lulu
 
  module Sigint_Trap
    # Module Trap is a SIGINT handler that interrupts in the main
    # thread (only when the thread is in the Ruby code)
    # by default it will 'puts' the current_job on the console
    # 
    # init()              sets up the SIGINT handler
    # add_work()           throws the SIGINT

    @work = []
    
    def self.init()
      @old_signal_handler = Signal.trap("INT") do
        current_job = @work.pop
        if current_job
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
    
    def self.add_work(val)
      @work << val
      Process.kill("INT", Process.pid)
    end
  end #sigint trap
 
  module Simple_server
    # a small webserver
    # call with http://localhost:2000/
    @html_body = <<-EOF
    <html><body><h2>HTML Forms</h2><form action="simple_server">First name:<br><input type="text" name="firstname" value="Mickey">
    <br>Last name:<br><input type="text" name="lastname" value="Mouse">
    <br><br><input type="submit" value="Submit"><input type="submit" name="stop_threads" value="Stop Threads"></form> 
    <p>If you click the "Submit" button, the form-data will be sent to a page called "simple_server".</p>
    </body></html>
    EOF
    @html_good = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nHello world! The time is "
    @html_not_found = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"

    def self.server_start()
      @t = Time.now
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
            #send the request to stdout
            Sigint_Trap.add_work((Time.now - @t).to_s + " " + request_uri)
            
            request_file = request_uri.split("?")[0]
            
            if request_file == '/favicon.ico'
              response << @html_not_found
            else
              response << @html_good + Time.now.to_s
              response << @html_body
            end
              session.print response
              session.close
        end
      rescue Errno::EPIPE
        Sigint_Trap.add_work('client disconnected')
        retry # client has disconnected
      rescue => e
        #send error messages from this thread to the ruby console
        Sigint_Trap.add_work(e.to_s + ', ' + e.backtrace.join("\n"))
      end
    end
  end #end simple server
  
  # a thread to demonstrate that we are alive
  # this thread wake-up when we are executing ruby code
  # i.e. not in a sketchup call or in a C extension.
  def self.worker1(proc)
    begin
      30.times do
        sleep(0.5)
        #x = 10/0
        Sigint_Trap.add_work(proc)
      end 
    rescue => e
      #send error messages from this thread to the ruby console
      Sigint_Trap.add_work(e.to_s + ', ' + e.backtrace.join("\n"))
    end
  end
  
  def self.start_work()
    puts 'start work'
    @t = Time.now
    proc = Proc.new {puts "#{Time.now - @t} Worker 1:"}
    @a = Thread.new {worker1(proc)}
    @a.priority = 4
    
    Simple_server.server_start()
  end
  
  def self.stop_work()
    @a.exit #kill the worker thread
    Simple_server.server_stop()
  end
   
  # initialize the sigint handler after load
  #start demo worker thread and server
  Sigint_Trap.init()
  start_work()
  puts "Got here"
 
  #open a web app window
  link = "http://localhost:2000"
  system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  #system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
  puts 'got there'
  
  # sleep and run an computing loop in the main thread
  # Threads will continue to run during this loop

  # start a timer that will not be triggered until we return from this module
  tim = UI.start_timer(0,false) {puts "#{(Time.now - @t).to_s}  UI timer"}

  @t = Time.now
  sleep(5.0)
  puts "#{(Time.now - @t).to_s} starting loop"
  x = 0
  until x == 50000000
   x += 1
  end
  puts "#{(Time.now - @t).to_s} end loop"
  sleep (5.0)
  
  stop_work()
  puts "#{(Time.now - @t).to_s} end module load"

end
