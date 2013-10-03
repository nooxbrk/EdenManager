# encoding: UTF-8
module System
  def create_account (name, password, options = {}) #Options : home_folder, group, loggable
    Open3.popen3("useradd #{name} #{"-d #{options[:home_folder]}" if !options[:home_folder].nil?} #{"-G #{options[:group]}" if !options[:group].nil?}  -m #{'-s /bin/false' if !options[:loggable]} -p $(mkpasswd -H md5 #{password})") {|stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
      if !stderr.nil?
        stderr.readlines.each do |e|
          error = e.gsub("\n", '')  # we do not want new lines
          case exit_status
            when 0 #all is fine
              Console.show error, 'warn'
              true
            when 6 #group doesn't exist
              #TODO: Report to the website the error
              Console.show error, 'error'
              false
            when 9 #user already exist
              #TODO: Report to the website the error
              Console.show error, 'error'
              false
            else
              #Unknown error, should be reported on edenservers' forum
              Console.show error, 'error'
              false
          end
        end
      else
        true
      end
    }
  end

  def delete_account (name, remove_home)
    Open3.popen3("deluser #{name} #{'--remove-home' if remove_home}") {|stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
      if !stderr.nil?
        stderr.readlines.each do |e|
          error = e.gsub("\n", '')  # we do not want new lines
          case exit_status
            when 0 #all is fine
              Console.show error, 'warn'
              true
            when 2 # There is no such user.
              #TODO: Report to the website the error
              Console.show error, 'error'
              false
            when 9 #trying to delete root account
              #TODO: Report to the website the error
              Console.show 'The manager doesn\'t allow to remove the root account', 'error'
              false
            else
              #Unknown error, should be reported on edenservers' forum
              Console.show error, 'error'
              false
          end
        end
      else
        true
      end
    }
  end

  def change_password (name, password)
    Open3.popen3("echo \"#{password}\" | passwd --stdin #{name}") {|stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
      if !stderr.nil?
        stderr.readlines.each do |e|
          error = e.gsub("\n", '')  # we do not want new lines
          case exit_status
            when 0 #all is fine
              Console.show error, 'warn'
              true
            when 1 # Permission denied : user invalid
              #TODO: Report to the website the error
              Console.show error, 'error'
              false
            when 5 # Passwd file busy
              #TODO: Report to the website the error
              Console.show error, 'error'
              false
            else
              #Unknown error, should be reported on edenservers' forum
              Console.show error, 'error'
              false
          end
        end
      else
        true
      end
    }
  end

  def apt_get(command, arguments = nil)
    Open3.popen3("apt-get -y --force-yes #{command} #{arguments}") {|stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
        stderr.readlines.each do |e|
          error = e.encode('UTF-8').gsub("\n", '')  # we do not want new lines
          case exit_status
            when 0 #all is fine
              Console.show error, 'warn'
              true
            else
              #Unknown error, should be reported on edenservers' forum
              Console.show error, 'error'
              return false
        end
      end
      true
    }
  end

  def gem(command, arguments = nil)
    Open3.popen3("gem #{command} #{arguments}") {|stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value.exitstatus
      stderr.readlines.each do |e|
        error = e.gsub("\n", '')  # we do not want new lines
        case exit_status
          when 0 #all is fine
            Console.show error, 'warn'
            true
          else
            #Unknown error, should be reported on edenservers' forum
            Console.show error, 'error'
            return false
        end
      end
      stdout.readlines.each do |l|
        msg = l.gsub("\n", '')
        Console.show msg, 'log'
      end
      true
    }
  end

  def daemonize_process
    Process.fork {
      # p1 is now running independent of, and parallel to the calling process
      Process.setsid
      p2 = Process.fork {
        # p2 is now running independent of, and parallel to p1
        $0 = 'EdenManager'
        File.umask 0000
        STDIN.reopen '/dev/null'
        STDOUT.reopen '/dev/null', 'a'
        STDERR.reopen STDOUT
        yield
        exit
      }
      Console.show "Manager started. Process id is #{p2}", 'info'
      exit
    }
  end

  def get_load_average
    load_avg = nil
    File.open('/proc/loadavg') {|f|
      load_avg = f.readline.split(' ')[2]
    }
    load_avg
  end

  def get_ram_usage
    mem_total = mem_free = mem_cached = nil;
    File.foreach('/proc/meminfo'){|l|
      case l
        when /MemTotal/
          mem_total = Float(l.split(' ')[1])
        when /MemFree/
          mem_free = Float(l.split(' ')[1])
        when %r{(?<!Swap)Cached}
          mem_cached = Float(l.split(' ')[1])
      end
    }
    100 - ((mem_free + mem_cached) / mem_total.to_f * 100).to_i
  end

end
include System