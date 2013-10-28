class LogParser
  def wake_time(file_name)
    wakeT = []
    auto_sleep_time = [] # last_HB_before_sleep - new_session_id_received
    get_new_session_time = [] #  new_session_id_received - first_HB_after_wake
    get_sleep_state_time = [] # session_sleeping_state - last_HB_before_sleep
    wake_up_time = [] # first_HB_after_wake - wake_command_sent     
 
    section = ""
    time = {}
    time[:hbt] = Time.now.to_i
    hb_time =[]
    File.foreach(file_name) do |line|
      case line
      when /Test cycle (\d+): starts/
        time[:cycle] = $1
        next
      when /heartbeat.*at .{10} (.*) \+0800$/
        hb_time.push $1
        time[:hb] = $1
        hbt_interval =  Time.now.to_i - time[:hbt].to_i # time in seconds since last heartbeat is received  
        if hbt_interval < 10 then
          time[:hbt_sleep] = time[:hb]
        elsif hbt_interval > 10 then
          time[:hbt_wake] = time[:hb]
          section = "finish"
        end
        time[:hbt] = Time.now.to_i
        next
      when /New session Id is received/
        section =  "new session"
        next
      when /Command sent: Wake Up/
        section = "wake command"
        next
      # when /Test setup: success/
      #   section = "setup"
      #   next
      when /Session state has changed from UNKNOWN to SLEEPING/
        section = "sleep"
        next
      # when /Test cycle \d+: succeeds |Test cycle \d+ failed|Test cycle \d+ fails/
      #   section = "finish"
      #   next
      end
     
      case section
      when "new session"
        section = ""      
        time[:sessionId] = line[/Logged TimeStamp:.{10} (.*) \+0800/,1]
        next
      when "sleep"
        section = ""      
        time[:sleep] = line[/Logged TimeStamp:.{10} (.*) \+0800/,1]
        next
      when "wake command"
        section = ""      
        time[:wake] = line[/Logged TimeStamp:.{10} (.*) \+0800/,1]
        next
      when "finish"
        section = ""
        wakeT.push time.dup
        time = {}
        next
      end
    end
    puts "cycle \t hbt_sleep \t sleep \t wake \t hbt_wake \t sessionId \n"
#    puts wakeT
    puts "HeartBeat timestamp"
    puts hb_time
    puts ''
    wakeT.each do |time|
      if time[:cycle].nil? then
         time[:cycle] = "NA"
      end
      if time[:hbt_sleep].nil? then
         time[:hbt_sleep] = "NA"
      end
      if time[:sleep].nil? then
         time[:sleep] = "NA"
      end
      if time[:wake].nil? then
         time[:wake] = "NA"
      end
      if time[:hbt_wake].nil? then
         time[:hbt_wake] = "NA"
      end
      if time[:sessionId].nil? then
         time[:sessionId] = "NA"
      end
      print time[:cycle],"\t"
      print time[:hbt_sleep],"\t"
      print time[:sleep],"\t"
      print time[:wake],"\t"
      print time[:hbt_wake],"\t"
      print time[:sessionId],"\t"
      print "\n"      
    end
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

end
