class ApiController < ApplicationController
  def login
    render :partial => "api/login.json"
  end

  def advertise
    render nothing: true
  end

  def heartbeat
    render :partial => "api/heartbeat.json"
  end

end
