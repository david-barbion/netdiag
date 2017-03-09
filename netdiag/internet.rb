require 'net/http'
require_relative '../netdiag-config'
require 'json'
require 'pp'

STATE_EEXPIRED=100

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
        if res[:result]
          quality += 100
        end
        count += 1
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
        return false if res[:result] == STATE_EEXPIRED 

        # usually, captive portal is done by
        # 1) sending a 302 to the client, redirecting to the portal, only works when client connect to http (not https)
        # 2) dns hijacking
        # 3) icmp redirect (not supported)
        if res[:result].is_a?(Net::HTTPSuccess) 
          body = JSON.parse(res[:result].body)
          return false if body["headers"]["Host"] == "httpbin.org"
        end
        raise "Get response code #{res[:result]}"
      rescue Exception => e
        puts "#{e.message}"
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
      rescue Net::OpenTimeout => e
        @error = e.message
        puts "get_uri(): timeout"
        ret[:result] = STATE_EEXPIRED
      rescue Exception => e
        @error = e.message
        puts "get_uri(): #{e.message}"
        ret[:result] = false
      end
      ret[:rtt] = Time.now - start
      return ret
    end
  end

end
