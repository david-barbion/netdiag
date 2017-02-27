require 'net/http'

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
        return true if res.is_a?(Net::HTTPSuccess)
        false
      rescue
        false
      end
    end
  end

end
