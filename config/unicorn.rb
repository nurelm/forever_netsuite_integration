@dir = File.expand_path(File.dirname(__FILE__))
listen File.join(@dir, "../unicorn.sock"), :backlog => 1024

# worker_processes 1 # NetSuite does not accept concurrency :(
worker_processes ENV.fetch('WORKER_PROCESSES', 1).to_i

timeout 240

preload_app true

GC.respond_to?(:copy_on_write_friendly=) and  GC.copy_on_write_friendly = true

before_fork do |server, worker|
  # kills old children after zero downtime deploy
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end

  sleep 1
end
