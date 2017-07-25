require 'net/http'
require_relative './config'
require 'json'

STATE_INTERNET_OK=0
STATE_INTERNET_EUNKNOWN=1
STATE_INTERNET_EEXPIRED=100

module Netdiag
  class Internet
    def initialize(url='http://httpbin.org/get')
      @url = url
      @count = 5
      @ret = Hash.new
      @last_rtt = 0
    end
  
    def prepare
      # clean last error
      @error = String.new
      true
    end

    def diagnose
      count = 0
      quality = 0.0
      rtt = 0.0
      (1..@count).each do
        res=self.get_uri
        if res[:result].is_a?(Net::HTTPSuccess)
          quality += 100
          count += 1
        end
        rtt += res[:rtt]
      end
      return 0 if count == 0
      @quality = quality / count
      @rtt = rtt / count
      @quality
    end
  
    def status
      return "Average rtt is #{rtt.round(2)}ms"
    end

    def is_captive?
      begin
        res = self.get_uri
        # internet can't be reached or test server unavailable
        # in this case, a captive portal cannot be detected, let's give a chance
        return false if res[:result] == STATE_INTERNET_EEXPIRED 

        # usually, captive portal is done by
        # 1) sending a 302 to the client, redirecting to the portal, only works when client connect to http (not https)
        # 2) dns hijacking (not supported)
        # 3) icmp redirect (not supported)
        return false if res[:result].is_a?(Net::HTTPSuccess) 
        raise "Get response code #{res[:result]}: #{@error}"
      rescue Exception => e
        puts "is_captive?(): #{e.message}"
        true
      end
    end

    def error
      @error
    end

    def raise_diag
      raise "Host not reachable" if !@quality
    end
  
    def get_uri
      ret = Hash.new
      start = Time.now
      begin
        uri = URI(@url)
        http = Net::HTTP.new(uri.host,uri.port)
        http.read_timeout = 3
        http.open_timeout = 3
        res = http.request_get(uri.path)
        ret[:result] = res
      rescue Net::OpenTimeout => e # Connection timeout
        @error = e.message
        puts "get_uri(): Net::OpenTimeout #{e.message}"
        ret[:result] = STATE_INTERNET_EEXPIRED
      rescue Net::ReadTimeout => e # Connection ok, but too long to respond
        @error = e.message
        puts "get_uri(): Net::ReadTimeout #{e.message}"
        ret[:result] = STATE_INTERNET_EEXPIRED
      rescue Exception => e
        @error = e.message
        puts "get_uri(): #{e.message}"
        ret[:result] = STATE_INTERNET_EUNKNOWN
      end
      ret[:rtt] = Time.now - start
      return ret
    end
  end

end
