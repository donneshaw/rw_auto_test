require 'wake_session'

class ApiController < ApplicationController
  layout false
  @@test_running = false
  @@sessionId = nil
  @@command = nil
  @@heartbeat_time  # the time when the latest heartbeat is received
  @@wake_success = false

  def login
    render file: Rails.root + "app/jsons/login.json" , content_type: "application/json"
  end

  def advertise
    render nothing: true
    session_id = params["RW_session_id"]

    if session_id.nil? then
      return
    end

    if session_id == @@sessionId then
      return # no new session id
    end
  
    @@sessionId = session_id
    puts "New session Id is received #{session_id}"
    log_time
  end

  def heartbeat
    @@heartbeat_time = Time.now.to_i
    if @@command.nil? then
      render file: Rails.root + "app/jsons/heartbeat.json" , content_type: "application/json"
    elsif @@command == "sleep" then
      render file: Rails.root + "app/jsons/heartbeat_sleep.json" , content_type: "application/json"
      @@command = nil
      # log the time when the sleep command is sent
      puts "Command sent: Sleep"
      log_time
    end
  end

  def rw_test1
    render nothing: true
    if @@sessionId.nil? then 
      puts "\n\nSessionId is nil"
      return
    end

    rw = WakeSession.new(@@sessionId)
    hash =  rw.state
    if hash.nil? then
      puts "\nGet nil response from Intel wake service when query session state."
      return
    end
    puts hash["Session"]["Status"]
    
  end  
  
  def log_time
    t = Time.now
    puts "Logged TimeStamp:#{t} | #{t.to_i}"
  end

  def rw_test1
    @@command = "sleep"
    render nothing: true
  end  

  def rw_test
    render nothing: true
    if @@test_running then
      return
    end
    
    Thread.new do |j|
      @@test_running = true
      # to run the test for 10 times
      puts "-------------------------- Test case starts to run -------------------------"
      log_time

      10.times do |i|
        puts "--------------test cycle: #{i} starts ---------------------------"
        if @@sessionId.nil? then 
          puts "\nSessionId is nil,wait for new session Id..."
          log_time
          10.times do
            if @@sessionId.nil? == false then
              puts "New sessionId is got."
              log_time
              break
            end
            sleep(4)
          end
          if @@sessionId.nil? then
            puts "----------------Test case execution abort because of nil sessionId! --------------"
            return
          end
        end

        # 1. put PC to sleep: send sleep command 

        @@command = "sleep"          

        # 2. Check session state to see if PC has gone to sleep
        rw = WakeSession.new(@@sessionId)
        @@wake_success = false
  
        # try to get the "Sleeping"  session state in 1 min. If not, regard that the "Sleep" command fail.
        status = "0"
        12.times do |k|
          puts "Check session state for cycle: #{k}"
          log_time
          hash =  rw.state
          if hash.nil? then
            puts "\nGet nil response from Intel wake service when query session state."
            puts "Failed check cycle: #{k} " 
            sleep(20)
            next
          end

          status = hash["Session"]["Status"]
          if status == "1" then
            puts "Session state has changed from UNKNOWN to SLEEPING"
            log_time
            break #todo: check if "break" jump out of the 12 times loop
          end

          sleep(5)
        end
        
        if status != "1" then
          # check if there's heartbeat in the last 10s from PC to verify if PC is really sleep.
          t = Time.now.to_i - @@heartbeat_time
          if t < 10 then
            puts "RemoteMonitor PC is still awake. The Sleep command failed."
          else
            puts "RemoteMonitor PC is not sending heartbeat, it may be in sleeping or disconnected from network."
          end
          # if there's heartbeat, then PC is not in sleeping state; otherwise PC is in sleeping state or disconnected from network.
          puts "Session state fails to change to 'Sleeping' after PC goes to sleep."
          rw = nil # to release the wakeSession object.
          # todo: jump to the next time of loop
          next
        end

        # 3. Send "Wake Up" command to PC 10s after it sleeps
        # todo: 
        #  a. log the time when "wake up" command is sent
        #  b. wait advertise/heartbeat from PC 
        sleep(10)
        rw.wake 
        @sesssionId = nil # to wait for new session Id
        puts "Command sent: Wake Up."
        log_time
        15.times do
          sleep(4)
          t = Time.now.to_i - @@heartbeat_time
          if t < 6 then 
            @@wake_success = true
            puts "Wake up the remoteMonitor PC successfully."
            log_time
            puts "--------------test cycle: #{i} succeeds ---------------------------"
            sleep(30) #wait 30s to get a new sessionId
            break
          end
        end
        
        if @@wake_success == false then
          puts "----------Wake up command failed in test cycle #{i}------------------------" 
          puts "----------Test case execution abort ------------------------------------"
          # todo: use Magic Packet to wake up the PC
          return
        end
      end
      puts "-------------------------- Test case execution complete -------------------------"
    
      @@test_running = false
    end
  end
end
