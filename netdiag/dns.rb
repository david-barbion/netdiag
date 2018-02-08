module Netdiag
  class DNS
    def initialize(name_to_resolve)
      @count = 0
      @name_to_resolve = name_to_resolve
    end

    def prepare
      @dns = Resolv::DNS.new
    end

    def diagnose
      @error = String.new
      count = 0
      begin
        self.resolve_ipv4(@name_to_resolve)
        count += 1
      rescue Exception => e
        @error << "#{e.message}\n"
      end
      begin
        self.resolve_ipv6(@name_to_resolve)
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
