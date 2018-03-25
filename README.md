# Sketchup-Ruby-Thread-Demo

Added: 'Lulu Threads with html console Demo 1.rb' which redirects Ruby Exception messages to the web console

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

