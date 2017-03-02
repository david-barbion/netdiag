require 'net/http'
require 'json'

module Netdiag
  class Internet
    def initialize(url='http://httpbin.org/get')
      @url = url
      @count = 5
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
        ret = JSON.parse(res.body)
        return true if ret["headers"]["Host"] = "httpbin.org"
        false
      rescue Exception => e
        puts e.message
        false
      end
    end
  end

end
