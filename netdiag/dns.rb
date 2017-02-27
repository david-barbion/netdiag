module Netdiag
  class DNS
    def initialize
      @dns = Resolv::DNS.new
    end
    def diagnose
      begin
        self.resolve_ipv4('root-servers.org')
        self.resolve_ipv6('root-servers.org')
      rescue Exception => e
        @error = e.message
        return false
      end
      @error = nil
      return true
    end
  
    def resolve_ipv4(name)
      @dns.getresource(name, Resolv::DNS::Resource::IN::AAAA)
    end
    def resolve_ipv6(name)
      @dns.getresource(name, Resolv::DNS::Resource::IN::A)
    end
  
  end
end
