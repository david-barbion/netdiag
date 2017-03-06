require 'pp'
module Netdiag
  class Local
  
    attr_reader :local_interfaces
    attr_reader :routed_addresses
    attr_reader :routes
    attr_reader :default_gateways
    def initialize
    end
  
    def prepare
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
      routes[:ipv4].each do |route|
        default_gateways.push(route["default"][:via]) if defined?(route["default"][:via]) and !route["default"][:via].nil?
      end
      routes[:ipv6].each do |route|
        default_gateways.push(route["default"][:via]) if defined?(route["default"][:via]) and !route["default"][:via].nil?
        default_gateways.push(route["2000::/3"][:via]) if defined?(route["2000::/3"][:via]) and !route["2000::/3"][:via].nil?
      end
      return default_gateways
    end
  
    def parse_routing_table
      routes = Hash.new
      routes[:ipv4] = Array.new
      f = IO.popen("ip -4 route show table main").each do |line|
        prefix = line.split.first
	route = Hash.new
        route[prefix] = Hash.new
        route[prefix][:dev] = $1 if line =~ /\s+dev\s+([^\s]+)/
        route[prefix][:scope] = $1 if line =~ /\s+scope\s+([^\s]+)/
        route[prefix][:metric] = $1 if line =~ /\s+metric\s+([^\s]+)/
        route[prefix][:proto] = $1 if line =~ /\s+proto\s+([^\s]+)/
        route[prefix][:src] = $1 if line =~ /\s+src\s+([^\s]+)/
        route[prefix][:via] = $1 if line =~ /\s+via\s+([^\s]+)/
        route[prefix][:weight] = $1 if line =~ /\s+weight\s+([^\s]+)/
        route[prefix][:table] = $1 if line =~ /\s+table\s+([^\s]+)/
        route[prefix][:error] = $1 if line =~ /\s+error\s+([^\s]+)/
        routes[:ipv4].push(route)
      end
      f.close
      routes[:ipv6] = Array.new
      f = IO.popen("ip -6 route show table main").each do |line|
        prefix = line.split.first
        route = Hash.new
        route[prefix] = Hash.new
        route[prefix][:dev] = $1 if line =~ /\s+dev\s+([^\s]+)/
        route[prefix][:scope] = $1 if line =~ /\s+scope\s+([^\s]+)/
        route[prefix][:metric] = $1 if line =~ /\s+metric\s+([^\s]+)/
        route[prefix][:proto] = $1 if line =~ /\s+proto\s+([^\s]+)/
        route[prefix][:src] = $1 if line =~ /\s+src\s+([^\s]+)/
        route[prefix][:weight] = $1 if line =~ /\s+weight\s+([^\s]+)/
        route[prefix][:table] = $1 if line =~ /\s+table\s+([^\s]+)/
        route[prefix][:error] = $1 if line =~ /\s+error\s+([^\s]+)/
        route[prefix][:via] = $1 if line =~ /\s+via\s+([^\s]+)/
        route[prefix][:via] = "#{route[prefix][:via]}%#{route[prefix][:dev]}" if
          route[prefix][:via] =~ /^f(e|c)/
        routes[:ipv6].push(route)
      end
      f.close
      routes
    end
  
  end
end
