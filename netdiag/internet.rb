require 'net/http'
require_relative './config'
require 'json'

STATE_INTERNET_OK=0
STATE_INTERNET_EUNKNOWN=1
STATE_INTERNET_EEXPIRED=100

module Netdiag
  class Internet
    def initialize
      @count = 5
      @ret = Hash.new
      @last_rtt = 0
    end
  
    def prepare
      @url        = Netdiag::Config.test_url
      @portal_url = Netdiag::Config.portal_test_url
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
        case res[:result]
        when Net::HTTPSuccess
          quality += 100
          count += 1
          @error = ""
        when STATE_INTERNET_EEXPIRED
          @error = "timeout"
        when STATE_INTERNET_EUNKNOWN
          @error = res[:error]
        when Net::HTTPServiceUnavailable
          @error = "service unavailable"
          quality += 75
          count += 1
        end
        rtt += res[:rtt]
      end
      return 0 if count == 0
      @quality = quality / count
      @rtt = rtt / count
      @quality
    end
  
    def message
      return "Internet rtt is #{@rtt.round(2)}ms, quality is #{@quality}%"
    end

    def status
      if @quality >= 50
        return "Internet test passed"
      else
        return "Internet test failed"
      end
    end

    def is_captive?
      # usually, captive portal is done by
      # 1) sending a 302 to the client, redirecting to the portal, only works when client connect to http (not https)
      # 2) dns hijacking (not supported)
      # 3) icmp redirect (not supported)
      # 4) mitm

      res = self.get_uri(@portal_url)
      # internet can't be reached or test server unavailable
      # in this case, a captive portal cannot be detected, let's give a chance
      return false if res[:result] == STATE_INTERNET_EEXPIRED or 
                      res[:result].is_a?(Net::HTTPServiceUnavailable)

      # detect absence of mitm (4)
      if res[:result].is_a?(Net::HTTPSuccess)
        json_response = parse_json_response(res[:result].body)
        return false if json_response.has_key?('args') && (json_response['args']['portal'] == '1')
      end

      # detected 302 (1) or 200 on mitm (4)
      if res[:result].is_a?(Net::HTTPResponse)
        $logger.warn("Got response code #{res[:result].code}")
        return true
      else
        $logger.warn("get_uri returned an error")
        return false
      end
    end

    def parse_json_response(body)
      begin
        JSON.parse(body)
      rescue
        { }
      end
    end

    def error
      @error
    end

    def raise_diag
      raise "Host not reachable" if !@quality
    end
  
    def get_uri(url=@url)
      ret = Hash.new
      start = Time.now
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host,uri.port)
        http.read_timeout = 3
        http.open_timeout = 3
        res = http.request_get(uri)
        ret[:result] = res
      rescue Net::OpenTimeout => e # Connection timeout
        puts "get_uri(): Net::OpenTimeout #{e.message}"
        ret[:result] = STATE_INTERNET_EEXPIRED
      rescue Net::ReadTimeout => e # Connection ok, but too long to respond
        puts "get_uri(): Net::ReadTimeout #{e.message}"
        ret[:result] = STATE_INTERNET_EEXPIRED
      rescue Exception => e
        puts "get_uri(): #{e.message}"
        ret[:result] = STATE_INTERNET_EUNKNOWN
        ret[:error] = e.message
      ensure
        http.finish if http.started?
      end
      ret[:rtt] = Time.now - start
      return ret
    end
  end

end
