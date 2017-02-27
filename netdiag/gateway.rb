require 'netdiag/pingip'
module Netdiag
  class Gateway
    def initialize(gateway_list, ping_count=5)
      @gateway_list = gateway_list
      @ping_count = ping_count
    end
  
    def diagnose
      count = 0
      quality = 0.0
      self.ping_gw.each do |res|
        quality = quality + (((res[:count].to_f-res[:failure].to_f)/res[:count].to_f)*100.0)
        if res[:rtt].nil?
          puts "ping error for #{res[:ip]}"
        elsif res[:rtt] >= 0.05 and res[:rtt] < 0.1
          quality = quality / 2
        elsif res[:rtt] >= 0.1 and res[:rtt] < 1
          quality = quality / 4
        elsif res[:rtt] >= 1
          quality = quality / 8
        end
        count += 1
      end
      return 0 if count == 0
      @quality = quality / count
      @quality
    end
  
    def raise_diag
      raise "Gateway not reachable" if !@quality
    end
  
    def ping_gw
      ping_gw = []
      @gateway_list.each do |gw|
        ping = PingIP.new(gw, @ping_count)
        ping_gw << ping.do
      end
      ping_gw
    end
  
  end
end
