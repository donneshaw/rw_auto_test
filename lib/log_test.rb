class LogParser
  def wake_time(file_name)
    auto_sleep_time = [] # last_HB_before_sleep - new_session_id_received
    get_new_session_time = [] #  new_session_id_received - first_HB_after_wake
    get_sleep_state_time = [] # session_sleeping_state - last_HB_before_sleep
    wake_up_time = [] # first_HB_after_wake - wake_command_sent     

    log_info = []
    File.foreach(file_name) do |line|
      case line
      when /heartbeat.*at .{10} (.*) \+0800$/
        log_info.push "HB:#{$1}"
        next
      when /New session Id is received/
        log_info.push "new_session_id_received"
        next
      when /Command sent: Wake Up/
        log_info.push "wake_command_sent"
        next
      when /Session state has changed from UNKNOWN to SLEEPING/
        log_info.push "session_sleeping_state"
        next
      when /Logged TimeStamp:.{10} (.*) \+0800/
        log_info.push "TS:#{$1}"
        next
      end
    end

    new_session_id_received = []
    new_session_id_received[0] = false

    last_HB_before_sleep = []

    session_sleeping_state = []
    session_sleeping_state[0] = false

    wake_command_sent = []
    wake_command_sent[0] = false

    first_HB_after_wake = []

    time_HB_old = nil
    time_HB_new = nil

    log_info.each do |item|
      case item
      when /new_session_id_received/
        new_session_id_received[0] = true
        next
      when /session_sleeping_state/
        session_sleeping_state[0] = true
        next
      when /wake_command_sent/
        wake_command_sent[0] = true
        next
      when /TS:(.*)/
        if new_session_id_received[0] == true then
          new_session_id_received.push $1
          new_session_id_received[0] = false
        elsif session_sleeping_state[0] == true then
          session_sleeping_state.push $1
          session_sleeping_state[0] = false
        elsif wake_command_sent[0] == true then
          wake_command_sent.push $1
          wake_command_sent[0] = false
        end
        next
      when /HB:(.*)/
        time_HB_old = time_HB_new
        time_HB_new = $1
        if time_HB_old.nil? then
          time_HB_old = $1
        end  
        if diff_HB(time_HB_old, time_HB_new) > 10 then
          last_HB_before_sleep.push time_HB_old
          first_HB_after_wake.push time_HB_new
        end
      end
    end
    puts "new_session_id_received"
    new_session_id_received.shift
    puts new_session_id_received
    
    
    puts "last_HB_before_sleep"
    puts last_HB_before_sleep

    puts "session_sleeping_state"
    session_sleeping_state.shift
    puts session_sleeping_state


    puts "wake_command_sent"
    wake_command_sent.shift
    puts wake_command_sent

    puts "first_HB_after_wake"
    puts first_HB_after_wake

    return true
  end

  def parse(file_name)
    section = []
 
    File.foreach(file_name) do |line|
      case line
      when /^Logged TimeStamp:(.*)$/
        section.push $1
        next
      when /^-+/
        section.push line
      end
    end

    stats = {}
    section.each do |line|
      case line
      when /Test cycle \d+: starts/
        stats[:start].nil? ? stats[:start]=1 : stats[:start] += 1
        next
      when /Test cycle \d+: succeeds/
        stats[:succeed].nil? ? stats[:succeed]=1 : stats[:succeed] += 1
        next
      when /Test cycle \d+ failed/
        stats[:failed].nil? ? stats[:failed]=1 : stats[:failed] += 1
        next
      when /Test cycle \d+ fails/
        stats[:fails].nil? ? stats[:fails]=1 : stats[:fails] += 1
      end 
    end
    puts stats
  end

  private
  
  def diff_HB(time_HB_old, time_HB_new)
  #format of time_HB_old: 12:11:10
    a1 = time_HB_old.split(':')
    a2 = time_HB_new.split(':')
  
    t1 = Time.new(2013,9,24,a1[0].to_i,a1[1].to_i,a1[2].to_i).to_i
    t2 = Time.new(2013,9,24,a2[0].to_i,a2[1].to_i,a2[2].to_i).to_i
  
    return t2 - t1
  end 

end
