require 'yaml'

# Symbolizes all of hash's keys and subkeys.
# Also allows for custom pre-processing of keys (e.g. downcasing, etc)
# if the block is given:
#
# somehash.deep_symbolize { |key| key.downcase }
#
# Usage: either include it into global Hash class to make it available to
#        to all hashes, or extend only your own hash objects with this
#        module.
#        E.g.:
#        1) class Hash; include DeepSymbolizable; end
#        2) myhash.extend DeepSymbolizable

module DeepSymbolizable
  def deep_symbolize(&block)
    method = self.class.to_s.downcase.to_sym
    syms = DeepSymbolizable::Symbolizers
    syms.respond_to?(method) ? syms.send(method, self, &block) : self
  end

  module Symbolizers
    extend self

    # the primary method - symbolizes keys of the given hash,
    # preprocessing them with a block if one was given, and recursively
    # going into all nested enumerables
    def hash(hash, &block)
      hash.inject({}) do |result, (key, value)|
        # Recursively deep-symbolize subhashes
        value = _recurse_(value, &block)

        # Pre-process the key with a block if it was given
        key = yield key if block_given?
        # Symbolize the key string if it responds to to_sym
        sym_key = key.to_sym rescue key

        # write it back into the result and return the updated hash
        result[sym_key] = value
        result
      end
    end

    # walking over arrays and symbolizing all nested elements
    def array(ary, &block)
      ary.map { |v| _recurse_(v, &block) }
    end

    # handling recursion - any Enumerable elements (except String)
    # is being extended with the module, and then symbolized
    def _recurse_(value, &block)
      if value.is_a?(Enumerable) && !value.is_a?(String)
        # support for a use case without extended core Hash
        value.extend DeepSymbolizable unless value.class.include?(DeepSymbolizable) 
        value = value.deep_symbolize(&block)
      end
      value
    end
  end
end

# extend Hash class of DeepSymbolizable, the global way

class Hash; include DeepSymbolizable; end
# source: http://speakmy.name/2011/05/29/simple-configuration-for-ruby-apps/
module Netdiag
  module Config
    # again - it's a singleton, thus implemented as a self-extended module
    extend self
  
    # Default settings here
    @_settings = {
      :theme    => 'iconic',
      :test_url => 'http://httpbin.org/get',
      :test_dns => 'root-servers.org',
      :gateways => {
                    :ipv4_mandatory => true,
                    :ipv6_mandatory => true,
                  }
    }
    attr_reader :_settings
  
    # This is the main point of entry - we call Settings.load! and provide
    # a name of the file to read as it's argument. We can also pass in some
    # options, but at the moment it's being used to allow per-environment
    # overrides in Rails
    def load!(filename, options = {})

      begin
        newsets = YAML::load_file(filename).deep_symbolize
      rescue Exception => e
        $stderr.puts "Couldn't load config file #{filename}: #{e.message}"
      end
      newsets = newsets[options[:env].to_sym] if \
                                                 options[:env] && \
                                                 newsets[options[:env].to_sym]
      deep_merge!(@_settings, newsets)
    end
  
    # Deep merging of hashes
    # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
    def deep_merge!(target, data)
      merger = proc{|key, v1, v2|
        Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      target.merge! data, &merger
    end
  
    def method_missing(name, *args, &block)
      @_settings[name.to_sym] ||
      fail(NoMethodError, "unknown configuration root #{name}", caller)
    end
  
  end
end
