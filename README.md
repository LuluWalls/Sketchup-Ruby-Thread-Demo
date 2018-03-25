# A Sketchup-Ruby-Threads-Demo

It is commonly thought that threads in ruby are crippled by being run in an embedded ruby environment. That is far from the truth. Ruby threads are scheduled to run anytime the 'main' thread is somewhere in the Ruby code, meaning not in a call into the sketchup core or into a compiled extension. In other words, threads are active during the same times as your ruby extension code is able to run. What is confusing is there is no easy way to communicate with STDOUT during times when the 'main' thread is busily processing ruby code. These demonstration files show a couple of backdoor methods you can use to monitor ruby threads without waiting for the main thread to sleep.

The first method raises an interrupt to gain access to the main thread and uses that ability to access STDOUT or execute a small ruby Proc. The second method creates a very small web server which servers both an interactive page for managing threads and a streaming page that can be written to like STDOUT.

Added: 'Lulu Threads with html console Demo 1.rb' which redirects Ruby Exception messages to a web interface.

## module Lulu
  ### module Sigint_Trap
  - ####  WARNING - Do not blithely add a SIGINT handler to your ruby code, it is not safe. This code is for demo purposes only!!!
  - Sigint_Trap is a SIGINT handler that interrupts the main Ruby thread (only when the thread is in the Ruby code) Sigint_Trap will either 'puts' the callers data to STDOUT or alternatively call a supplied Proc object on the main thread.
    
### module Simple_server
  - A small webserver running on a Ruby thread. Call with http://localhost:2000/
    
### utility methods
- start_work - start threads
- stop_work - shut down threads

