#!/usr/bin/env ruby


$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'pp'
# NetworkLocal
require 'socket'
require 'net/ping'
require 'resolv'
require "netdiag/local"
require "netdiag/gateway"
require "netdiag/dns"
require "netdiag/internet"

local = Netdiag::Local.new
if !local.diagnose
  exit 1
end

gateway = Netdiag::Gateway.new(local.default_gateways)
if gateway.diagnose < 50
  exit 2
end

dns = Netdiag::DNS.new
if !dns.diagnose
  exit 3
end

internet = Netdiag::Internet.new
if internet.diagnose < 50
  exit 5
end
