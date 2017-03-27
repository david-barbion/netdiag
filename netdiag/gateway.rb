require 'netdiag/pingip'
module Netdiag
  class Gateway
    def initialize(args={})
      @ping_count = args[:ping_count] ? args[:ping_count] : 5
      @ipv4_mandatory = args[:ipv4_mandatory] ? args[:ipv4_mandatory] : true
      @ipv6_mandatory = args[:ipv6_mandatory] ? args[:ipv6_mandatory] : true
      @analysis = Hash.new
    end
  
    def prepare(gateway_list)
      @have_ipv4 = false
      @have_ipv6 = false
      @gateway_list = gateway_list
      @gateway_list.each do |gw|
        case gw.gsub(/%.*/, '')
        when Resolv::IPv4::Regex
          @have_ipv4 = true
        when Resolv::IPv6::Regex
          @have_ipv6 = true
        end
      end
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
      quality /= 2.0 if ( @ipv4_mandatory and !@have_ipv4 ) 
      quality /= 2.0 if ( @ipv6_mandatory and !@have_ipv6 )
      @quality = quality / count
      @quality
    end
  
    def message
      message = String.new
      if @ipv4_mandatory and !@have_ipv4 
        message << "IPv4 gateway not found, check your local configuration or DHCP server\n"
      elsif @ipv6_mandatory and !@have_ipv6
        message << "IPv6 gateway not found, check your local configuration or network advertiser\n"
      else
        begin
          @analysis.each do |ip,res|
            message << "#{ip} (#{res[:count]-res[:failure]}/#{res[:count]}, rtt=#{res[:rtt].round(2)}ms, quality=#{res[:quality].round(2)}%)\n"
          end
        rescue Exception => e
          message = "Can't compute analysis: #{e.message}"
        end
      end
      return message
    end

    def status
      return "No IPv4 gateway found" if ( @ipv4_mandatory and !@have_ipv4 ) 
      return "No IPv6 gateway found" if ( @ipv6_mandatory and !@have_ipv6 ) 
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
