require_relative '../netdiag-config'
module Netdiag
  class DNS
    def initialize
      @dns = Resolv::DNS.new
      @config = Netdiag::Config.new
      @count = 0
    end

    def prepare
      true
    end

    def diagnose
      @error = String.new
      count = 0
      begin
        self.resolve_ipv4(@config.get_test_dns)
        count += 1
      rescue Exception => e
        @error << "#{e.message}\n"
      end
      begin
        self.resolve_ipv6(@config.get_test_dns)
        count += 1
      rescue Exception => e
        @error << "#{e.message}\n"
      end
      @count = count
      return false if count==0
      return true
    end
  
    def message
      return "Received #{@count} packet(s) from DNS server" 
    end

    def error
      @error
    end

    def resolve_ipv4(name)
      @dns.getresource(name, Resolv::DNS::Resource::IN::A)
    end
    def resolve_ipv6(name)
      @dns.getresource(name, Resolv::DNS::Resource::IN::AAAA)
    end
  
  end
end
