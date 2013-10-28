require 'uri'
require 'base64'
require 'openssl'
require 'net/http'
require 'net/https'
require 'httparty'
require 'socket'

class WakeSession
 
  def initialize(sessionId=nil)
    if sessionId.nil? then
      @sessionId = '8A22610E-B460-5CB6-40D0-DE0987FA685B'
    else
      @sessionId = sessionId 
    end
    @wakeServerUrl = 'https://wr-1us.smartconnect.intel.com/sessions/'
    @apiKeyId = "76F21038-5826-47F1-8899-A272A34B693E"
    @apiKeySecret = "NzE3OTRERUVGRDdBNDZGMkFBOUY5NDJEMzVENkVDQUM="
  end
  
  def genReqUrl(apiName, readToken=nil)
  
    sessionId = @sessionId
    wakeServerUrl = @wakeServerUrl
    baseUrl = wakeServerUrl + sessionId

    case apiName
      when "getSessionState"
        baseUrl = wakeServerUrl + sessionId
      
      when "wake"
        baseUrl = wakeServerUrl + sessionId + '/wakerequests'
        
      when "subscribe", "unSubscribe"
        baseUrl = wakeServerUrl + sessionId + '/subscriptions'
        
      when "readUpdates"
        baseUrl = wakeServerUrl + sessionId + '/updates'
      
      when "acknowledgeUpdates"
        baseUrl = wakeServerUrl + sessionId + '/updates' + "#{readToken}"
        
      else
        print "process as apiName is getSessionState"
    end
    
    apiKeyId = @apiKeyId
    apiKeySecret = @apiKeySecret

    url = URI.parse(baseUrl)
    url.query = "apikeyid=" + apiKeyId

    path_query = url.path.to_s + '?' + url.query.to_s
    data = path_query.force_encoding("UTF-8")
    key = Base64.decode64(apiKeySecret)
    sha256 = OpenSSL::Digest::SHA256.new
    sign1 = OpenSSL::HMAC.digest(sha256, key, data)
    sign2 = Base64.encode64(sign1).strip
    signature = URI.encode_www_form_component(sign2)

    final_url = url.to_s + '&signature=' + signature
    # print "#{final_url}"
    return final_url
  end
    
  def request
    rootCA = 'd:\ssl\certs\cacert.pem'

    url = URI.parse(getSessionUrl)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')
    if (File.exists?(rootCA) && http.use_ssl?)
      http.ca_file = rootCA
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_depth = 5
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
    end
    req = Net::HTTP::Get.new(url.path)
    req.initialize_http_header({"accept" => "application/json","content-type"=>"application/json"})
    resp = http.request(req)
  end
  
  def state
    url = genReqUrl("getSessionState")
    HTTParty.get(url).parsed_response
  end
  
  def wake
    url = genReqUrl("wake")
    HTTParty.post(url, 
      :body =>'{}', 
      :headers => { 'Content-Type' => 'application/json' } )
  end
  
  def sub
    url = genReqUrl("subscribe")
    HTTParty.post(url, 
      :body => '{}',  # this is not mentioned in the API doc 
      :headers => { 'Content-Type' => 'application/json' } )
  end
  
  def unSub
    url = genReqUrl("unSubscribe")
    HTTParty.delete(url, 
      :headers => { 'Content-Type' => 'application/json' } )
  end  
  
  def read
    url = genReqUrl("readUpdates")
    HTTParty.get(url, 
      :headers => { 'Content-Type' => 'application/json' } )
  end
  
  def ack
    url = genReqUrl("acknowledgeUpdates")
    HTTParty.delete(url, 
      :headers => { 'Content-Type' => 'application/json' } )
  end 

  def sendMagicPkt
    #macAddr = '3C:A9:F4:42:C7:74' # todo: comment this line after test.
    # todo: set ruby default encoding to UTF-8
    macAddr = "3C:A9:F4:50:E7:E8".force_encoding("ASCII-8BIT") 
    # macAddr = "B4:B6:76:78:E9:FC".force_encoding("ASCII-8BIT") # CH_XPS12_1_RW
  
    begin
      addr = ['<broadcast>', 9]
      udpSock = UDPSocket.new
      udpSock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      data = "\xFF\xFF\xFF\xFF\xFF\xFF".force_encoding("ASCII-8BIT")
      puts data.encoding
      puts macAddr.encoding
      arr = macAddr.split(':')
      16.times do |i|
        data<< arr[0].hex.chr+arr[1].hex.chr+arr[2].hex.chr+arr[3].hex.chr+arr[4].hex.chr+arr[5].hex.chr
      end
      puts("Wake-On-Lan packet sent to MAC address " + macAddr)
      udpSock.send(data, 0, addr[0], addr[1])
    rescue Exception => msg
      puts msg
    end
  end
  
end
