require 'net/http'
require_relative '../netdiag-config'
require 'json'
require 'pp'

module Netdiag
  class Internet
    def initialize(url='http://httpbin.org/get')
      @url = url
      @count = 5
      @ret = Hash.new
    end
  
    def diagnose
      count = 0
      quality = 0
      (1..@count).each do
        if self.get_uri
          quality += 100
        end
        count += 1
      end
      return 0 if count == 0
      @quality = quality / count
      @quality
    end
  
    def is_captive?
      if @body["headers"]["Host"] != "httpbin.org"
        true
      end
      false
    end

    def raise_diag
      raise "Host not reachable" if !@quality
    end
  
    def get_uri
      begin
        uri = URI(@url)
        http = Net::HTTP.new(uri.host,uri.port)
        http.read_timeout = 1
        http.open_timeout = 1
        res = http.request_get(uri.path)
        if res.is_a?(Net::HTTPSuccess)
          @body = JSON.parse(res.body)
        end
        return true if @body["headers"]["Host"] = "httpbin.org"
        false
      rescue Exception => e
        puts e.message
        false
      end
    end
  end

end
