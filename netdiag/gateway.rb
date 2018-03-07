require 'netdiag/pingip'
require_relative './config'
module Netdiag
  class Gateway
    attr_reader :ipv4_quality, :ipv6_quality, :have_ipv4, :have_ipv6, :ipv4_mandatory, :ipv6_mandatory

    def initialize(args={})
      @ping_count = args[:ping_count] ? args[:ping_count] : 5
    end
  
    def prepare(gateway_list)
      @analysis = Hash.new
      @have_ipv4 = false
      @have_ipv6 = false
      @ipv4_quality = 0
      @ipv6_quality = 0
      @ipv4_mandatory = Netdiag::Config.gateways[:ipv4_mandatory]
      @ipv6_mandatory = Netdiag::Config.gateways[:ipv6_mandatory]
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

    def is_ipv4_gateway_missing
      return false if !@ipv4_mandatory
      return !@have_ipv4
    end

    def is_ipv6_gateway_missing
      return false if !@ipv6_mandatory
      return !@have_ipv6
    end

    def check_gateway_threshold(threshold=50)
      ((@ipv4_mandatory && @ipv6_mandatory) && diagnose <= threshold) ||
      ((@ipv4_mandatory || @ipv6_mandatory) && diagnose <  threshold)
    end

    def get_gw_quality(gw)
      @analysis[gw][:quality]
    end

    def diagnose
      count = 0
      quality = 0.0
      global_quality = 0.0
      self.ping_gw.each do |res|
        quality = (((res[:count].to_f-res[:failure].to_f)/res[:count].to_f)*100.0)
        global_quality += quality
        if res[:rtt].nil?
          $logger.error("#{self.class.name}::#{__method__.to_s} ping error for #{res[:ip]}")
        elsif res[:rtt] >= 0.05 and res[:rtt] < 0.1
          quality = quality / 1.2
        elsif res[:rtt] >= 0.1 and res[:rtt] < 1
          quality = quality / 1.7
        elsif res[:rtt] >= 1
          quality = quality / 2
        end
        count += 1
        @analysis[res[:ip]] = res
        # this is to compute quality per protocol
        case res[:ip].gsub(/%.*/, '')
        when Resolv::IPv4::Regex
          @ipv4_quality += quality
          @analysis[res[:ip]][:quality] = quality
        when Resolv::IPv6::Regex
          @ipv6_quality += quality
          @analysis[res[:ip]][:quality] = quality
        end
      end
      return 0 if count == 0 
      global_quality /= 2.0 if ( @ipv4_mandatory and !@have_ipv4 ) 
      global_quality /= 2.0 if ( @ipv6_mandatory and !@have_ipv6 )
      @quality = global_quality / count
      @quality
    end
  
    def message(short=false)
      message = []
      if @ipv4_mandatory and !@have_ipv4 
        message << (short ? "IPv4 gateway not found" : "IPv4 gateway not found, check your local configuration or DHCP server")
      elsif @ipv6_mandatory and !@have_ipv6
        message << (short ? "IPv6 gateway not found" : "IPv6 gateway not found, check your local configuration or network advertiser")
      else
        begin
          @analysis.each do |ip,res|
            if res[:rtt].nil?
              message << (short==true ? "#{ip} failed" : "#{ip} (#{res[:count]-res[:failure]}/#{res[:count]})")
            else
              message << (short==true ? "#{ip} (quality: #{res[:quality].round(2)}%)" : "#{ip} (#{res[:count]-res[:failure]}/#{res[:count]}, rtt=#{res[:rtt].round(2)}ms, quality=#{res[:quality].round(2)}%)")
            end
          end
        rescue Exception => e
          message << "Can't compute analysis: #{e.message}"
        end
      end
      return message.join("\n");
    end

    def status
      return "No IPv4 gateway found" if ( @ipv4_mandatory and !@have_ipv4 ) 
      return "No IPv6 gateway found" if ( @ipv6_mandatory and !@have_ipv6 ) 
      @analysis.each do |ip,res|
        if (@ipv4_mandatory and ip =~ Resolv::IPv4::Regex) or (@ipv6_mandatory and ip =~ Resolv::IPv6::Regex)
          if res[:rtt].nil? and 
            return "Default gateway unreachable"  
          elsif res[:rtt] > 0.1
            return "Detected high latency on gateway #{ip}"
          end
        end
      end
      if @quality <= 50
        return "Default gateway partially reachable (packet loss)"
      end

      return "Gateway test passed"
    end

    def raise_diag
      raise "Gateway not reachable" if !@quality
    end
  
    def ping_gw
      ping_gw = []
      @gateway_list.each do |gw|
        $logger.debug("#{self.class.name}::#{__method__.to_s} sending ping to '#{gw}'")
        ping = PingIP.new(gw, @ping_count)
        ping_gw << ping.do
      end
      ping_gw
    end
  
  end
end
