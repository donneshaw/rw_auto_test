require 'wake_session'

class ApiController < ApplicationController
  layout false
  @@test_running = false  # to limit that only one thread of test execution is running
  @@sessionId = nil
  @@command = nil
  @@heartbeat_time = 0  # the time when the latest heartbeat is received
  TEST_TIMES = 10

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
    logger.info "-------- New session Id is received: #{session_id} -----------"
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
      logger.info "------------------ Command sent: Sleep ------------------"
      log_time
    end
  end

  def log_time
    t = Time.now
    logger.info "Logged TimeStamp:#{t} | #{t.to_i}"
  end

  def rw_test
    render nothing: true
    if @@test_running then
      return
    end
    
    Thread.new do 
      @@test_running = true
      # to run the test for 10 times
      logger.info "\n"
      logger.info "-------------------------- Test case starts to run -------------------------"
      logger.info "------------------- Total #{TEST_TIMES} cycles to be run --------------------"
      log_time

      TEST_TIMES.times do |i|
        
        # 1. setup test preconditions:
        # preconditions for a new test cycle:
        # a. a valid session id is got.
        # b. RemoteMonitor PC is in sleeping.
        if setup == false then
          logger.info "\n"
          logger.info "------------------ Test setup failed, test execution aborted ------------------"
          return
        end
        logger.info "----------------------- Test cycle #{i}: starts ---------------------------"

        # 2. Check session state 
        rw = WakeSession.new(@@sessionId)
        hash =  rw.state
        if hash.nil? then
          logger.info "---------- start to check session response in test cycle #{i} ----------------"
          log_time 
          gd_time = 0 # guard time
          begin
            sleep(4)
            hash =  rw.state
            gd_time += 4
          end while hash.nil? and gd_time < 60
          logger.info "---------- finish checking session response in test cycle #{i} ----------------"
          if hash.nil? then
            logger.info "----------- fail to get valid session response from Intel RW service --------"
            logger.info "---------------------- Test abort in test cycle #{i}-------------------------"
            log_time 
            return 
          end
        end

        # try to get the "Sleeping"  session state in 2 min. If not, regard that the "Sleep" command fail.
        status = hash["Session"]["Status"]
        gd_time = 0
        logger.info "---------- start to check session status in test cycle #{i} ----------------"
        log_time
        while status == "0" and gd_time < 120 do
          sleep(5)
          gd_time += 5
          hash = rw.state
          status = hash["Session"]["Status"]
        end        
        logger.info "----------finish checking session status in test cycle #{i} ----------------"
        log_time
                 
        if status == "1" then
          logger.info "------------- Session state has changed from UNKNOWN to SLEEPING ------------"
          log_time
        else
          logger.info "----- Session state fails to change to 'Sleeping' after PC goes to sleep.-------"
          rw = nil # to release the wakeSession object.
          logger.info "------------------Test cycle #{i} fails -------------------------- "
          @@sessionId = nil
          next
        end

        # 3. Send "Wake Up" command to wake PC up
        sleep(10)
        rw.wake 
        @@sessionId = nil # to wait for new session Id
        logger.info "----------------- Command sent: Wake Up.-------------------------"
        log_time
        # wait for heartbeat
        gd_time = 0
        while (Time.now.to_i - @@heartbeat_time) > 10 and gd_time < 60 do
          sleep(4)
          gd_time += 4
        end
        t = Time.now.to_i - @@heartbeat_time
        if t < 6 then 
          logger.info "--------------- Wake up the remoteMonitor PC successfully.---------------"
          logger.info "------------------- Test cycle #{i}: succeeds ---------------------------"
          log_time
        else
          logger.info "------------ Wake up command failed in test cycle #{i} --------------------" 
          logger.info "------------------------ Test cycle #{i} failed ---------------------------" 
          log_time
        end
      end
      logger.info "-------------------------- Test case execution complete -------------------------"
      @@test_running = false
    end
  end

  def rw_test_temp
    render nothing: true
    if @@sessionId.nil? then 
      logger.info "\n\nSessionId is nil"
      return
    end

    rw = WakeSession.new(@@sessionId)
    hash =  rw.state
    if hash.nil? then
      logger.info "\nGet nil response from Intel wake service when query session state."
      return
    end
    logger.info hash["Session"]["Status"]
  end  

  def rw_test_sleep
    @@command = "sleep"
    render nothing: true
  end  

  def rw_test_wake
    render nothing: true
    rw = WakeSession.new(@@sessionId)
#    rw.wake
    rw.sendMagicPkt

  end  

private 

  def setup
    # make preconditions for a test cycle:
    # 1. sessionId is not nil
    # 2. RemoteMonitor PC is in sleeping.(No heartbeat received in the past 10s)
    logger.info "------------------------- Test setup: start ---------------------------"
    logger.info "-------------------- Start to wait for new session Id -----------------"
    log_time
    guard_time = 0
    logger.info "-------------------- sessionId: #{@@sessionId} ------------------------"
    while @@sessionId.nil? do
      if guard_time > 60*5 then
        logger.info "---------------- Test setup failed to get session Id within guard time -------------"
        log_time
        return false
      end
      #if heartbeat stopped, try to wake the PC by Magic Packet, at most try for 2 times
      2.times do
        if (Time.now.to_i - @@heartbeat_time) > 10 then
          rw = WakeSession.new
          rw.sendMagicPkt
          log_time
          @sessionId = nil # to wait for new session Id
          sleep(10)
        end
      end        
      
      # if (Time.now.to_i - @@heartbeat_time) > 10 then
      #   # 2 times of Magic Packets fail to wake up the PC
      #   # setup fail
      #   logger.info "--------------- Magic Packet fail to wake up RemoteMonitor PC for 2 times ---------------"
      #   return false       
      # end

      # PC is sending HB, check session Id every 4s
      sleep(4)
      guard_time += 4
    end 

    # wait for PC to sleep(stop sending heartbeat)
    guard_time = 0
    while (Time.now.to_i - @@heartbeat_time) < 10 do
      if guard_time > 60*2 then
        @@command = "sleep"          
        logger.info "-------------- Test setup failed to wait for PC to auto sleep within guard time -------------"
        logger.info "-------------- Test setup sent sleep command to make PC to sleep ---------------------"
        log_time
        break
      end
      sleep(4)
      guard_time += 4
    end

    # wait for PC to sleep after sending "Sleep" command 
    guard_time = 0
    while (Time.now.to_i - @@heartbeat_time) < 10 do
      if guard_time > 60*2 then
        logger.info "-------------- Test setup failed to wait for PC to sleep within guard time -------------"
        log_time
        return false
      end
      sleep(4)
      guard_time += 4
    end

    logger.info "------------------------------------ Test setup: success -----------------------------------"
    log_time
    return true
  end

end
