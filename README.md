# A Sketchup-Ruby-Threads-Demo

It is commonly thought that threads in ruby are crippled by being run in an embedded ruby environment. That is far from the truth. Ruby threads are schedule to run anytime the 'main' thread is somewhere inn the Ruby code, meaning not in a call into the sketchup core or into a compiled extension. In other words, threads are active during the same times as your ruby extension code is able to run. What is confusing is there is no easy way to communicate with STDOUT during times when the 'main' thread is busily process ruby code. These demonstration files show a couple of backdoor methods you can use to monitor ruby threads without waiting for the main thread to sleep.

Added: 'Lulu Threads with html console Demo 1.rb' which redirects Ruby Exception messages to a web console

## module Lulu
  ### module Sigint_Trap
  - ####  WARNING - Do not blithely add a SIGINT handler to your ruby code, it is not safe. This code is for demo purposes only!!!
  - Sigint_Trap is a SIGINT handler that interrupts the main Ruby thread (only when the thread is in the Ruby code) Sigint_Trap will either 'puts' the callers data to STDOUT or alternatively call a supplied Proc object on the main thread.
    
### module Simple_server
  - A small webserver running on a Ruby thread. Call with http://localhost:2000/
    
### utility methods
- start_work - start threads
- stop_work - shut down threads
- worker1 - a utility thread that alternatively sleeps and runs

This is followed by a set of sleep and run loops that execute on the main thread and show that the subthreads do indeed continue to operate while the main thread is busy with ruby code. A final note, the UI.timer created on the main thread does not fire until
this module returns the thread to Ruby control.
