module Netdiag
  class Local
  
    attr_reader :local_interfaces
    attr_reader :routed_addresses
    attr_reader :routes
    attr_reader :default_gateways
    def initialize
      @routes           = self.parse_routing_table
      @local_interfaces = self.get_address_list
      @routed_addresses = self.have_routed_address(@local_interfaces)
      @default_gateways = self.get_default_gateway_list(@routes)
    end
  
    # diagnose local interface
    # at least, one interface should have
    # one IPv4 and optionaly IPv6
    def diagnose
      if @routed_addresses.count >= 1 and @default_gateways.count >= 1
        return true
      else
        return false
      end
    end
  
    def raise_diag
      raise "No address found" if @routed_addresses.count == 0
      raise "No gateway found" if @default_gateways.count == 0
    end
  
    def get_address_list
      return local_interfaces = Socket.getifaddrs.each_with_object({}) do |i, hash|
          if (i.addr and (i.addr.ipv4? or i.addr.ipv6?))
            hash[i.name] ||=[]
            hash[i.name] << {:address => i.addr.ip_address,
                             :netmask   => i.netmask.ip_address,
                             :flags     => i.flags
                            }
          end
      end
    end
  
    def have_routed_address(address_list)
      routed_addresses = Array.new
      address_list.each do |name,ifdata|
        next if name =~ /^lo$/
        ifdata.each do |interface|
          next if  interface[:address] =~ /^(127|fc..:|fe80:)/
           routed_addresses.push(interface[:address])
        end
      end
      return routed_addresses
    end
  
    def get_default_gateway_list(routes=@routes)
      default_gateways = Array.new
      default_gateways.push(routes[:ipv4]["default"][:via]) if defined?(routes[:ipv4]["default"][:via])
      default_gateways.push(routes[:ipv6]["default"][:via]) if defined?(routes[:ipv6]["default"][:via])
      return default_gateways
    end
  
    def parse_routing_table
      routes = Hash.new
      routes[:ipv4] = Hash.new
      f = IO.popen("ip -4 route show table main").each do |line|
        prefix = line.split.first
        routes[:ipv4][prefix] = Hash.new
        routes[:ipv4][prefix][:dev] = $1 if line =~ /\s+dev\s+([^\s]+)/
        routes[:ipv4][prefix][:scope] = $1 if line =~ /\s+scope\s+([^\s]+)/
        routes[:ipv4][prefix][:metric] = $1 if line =~ /\s+metric\s+([^\s]+)/
        routes[:ipv4][prefix][:proto] = $1 if line =~ /\s+proto\s+([^\s]+)/
        routes[:ipv4][prefix][:src] = $1 if line =~ /\s+src\s+([^\s]+)/
        routes[:ipv4][prefix][:via] = $1 if line =~ /\s+via\s+([^\s]+)/
        routes[:ipv4][prefix][:weight] = $1 if line =~ /\s+weight\s+([^\s]+)/
        routes[:ipv4][prefix][:table] = $1 if line =~ /\s+table\s+([^\s]+)/
        routes[:ipv4][prefix][:error] = $1 if line =~ /\s+error\s+([^\s]+)/
      end
      f.close
      routes[:ipv6] = Hash.new
      f = IO.popen("ip -6 route show table main").each do |line|
        prefix = line.split.first
        routes[:ipv6][prefix] = Hash.new
        routes[:ipv6][prefix][:dev] = $1 if line =~ /\s+dev\s+([^\s]+)/
        routes[:ipv6][prefix][:scope] = $1 if line =~ /\s+scope\s+([^\s]+)/
        routes[:ipv6][prefix][:metric] = $1 if line =~ /\s+metric\s+([^\s]+)/
        routes[:ipv6][prefix][:proto] = $1 if line =~ /\s+proto\s+([^\s]+)/
        routes[:ipv6][prefix][:src] = $1 if line =~ /\s+src\s+([^\s]+)/
        routes[:ipv6][prefix][:weight] = $1 if line =~ /\s+weight\s+([^\s]+)/
        routes[:ipv6][prefix][:table] = $1 if line =~ /\s+table\s+([^\s]+)/
        routes[:ipv6][prefix][:error] = $1 if line =~ /\s+error\s+([^\s]+)/
        routes[:ipv6][prefix][:via] = $1 if line =~ /\s+via\s+([^\s]+)/
        routes[:ipv6][prefix][:via] = "#{routes[:ipv6][prefix][:via]}%#{routes[:ipv6][prefix][:dev]}" if
          routes[:ipv6][prefix][:via] =~ /^f(e|c)/
      end
      f.close
      routes
    end
  
  end
end
