require 'netdiag/pingip'
module Netdiag
  class Gateway
    def initialize(gateway_list, ping_count=5)
      @gateway_list = gateway_list
      @ping_count = ping_count
      @analysis = Hash.new
    end
  
    def diagnose
      count = 0
      quality = 0.0
      self.ping_gw.each do |res|
        quality = quality + (((res[:count].to_f-res[:failure].to_f)/res[:count].to_f)*100.0)
        if res[:rtt].nil?
          puts "ping error for #{res[:ip]}"
        elsif res[:rtt] >= 0.05 and res[:rtt] < 0.1
          quality = quality / 1.2
        elsif res[:rtt] >= 0.1 and res[:rtt] < 1
          quality = quality / 1.7
        elsif res[:rtt] >= 1
          quality = quality / 2
        end
        count += 1
        @analysis[res[:ip]] = res
        @analysis[res[:ip]][:quality] = quality
      end
      return 0 if count == 0
      @quality = quality / count
      @quality
    end
  
    def message
      message = String.new
      begin
        @analysis.each do |ip,res|
          message << "#{ip} (#{res[:count]-res[:failure]}/#{res[:count]}, rtt=#{res[:rtt].round(2)}ms, quality=#{res[:quality].round(2)}%)\n"
        end
      rescue Exception => e
        message = "Can't compute analysis: #{e.message}"
      end
      return message
    end

    def status
      @analysis.each do |ip,res|
        if res[:rtt] > 0.1
          return "Detected high latency on gateway #{ip}"
        end
      end
      if @quality < 50
        return "Default gateway partially reachable (packet loss)"
      end
      return "Gateway problem"
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
