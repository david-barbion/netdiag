require 'net/ping'
module Netdiag
  class PingIP
    attr_reader :data
    def initialize(ip, count, timeout=1)
      @ip = ip
      @timeout = timeout
      @port = 9
      @data = Hash.new
      @count = count
      @ping = Net::Ping::External.new(ip, nil, timeout)
    end
  
    def do
      rtt = Array.new
      no_response = 0
      (1..@count).each do |count|
        begin
          rtt << self.do_ping
        rescue Exception => err
          no_response += 1
      #    puts "#{err.message} for #{@ip}"
      #    puts err.backtrace
        end
      end
  
      begin
        @data[:rtt] = rtt.inject(0) {|sum, i| sum + i}/(@count - no_response)
      rescue
        @data[:rtt] = nil
      end
      @data[:failure] = no_response
      @data[:count] = @count
      @data[:ip] = @ip
      @data
    end
  
    MAX_DATA = 64
    def do_ping
      bool = false
  
      start_time = Time.now
  
      if @ping.ping
        bool = true
      end
      @duration = Time.now - start_time if bool
      raise 'ping timeout' if not bool
      @duration
    end
  
  end
end
