require 'dbus'

module Netdiag
  class Notify
  
    attr_accessor :icon_dirs
    @icon_dirs = [
      "/usr/share/icons/gnome/*/emblems",
      "/usr/share/icons/gnome/*/emotes"
    ]

   	@@interface = nil
  	DEFAULTS = {
  		app_name: __FILE__,
  		id:       0,
  		icon:     'info',
  		summary:  '',
  		body:     '',
  		actions:  [],
  		hints:    {},
  		timeout:  2000,
  	}
  
  	def self.send(first, *others)
  		if first.is_a?(Hash) and others.length == 0
  			_send first
  		elsif first.respond_to?(:to_s) and others.length < 4
        _send [:body, :icon, :timeout].zip(others).each_with_object({summary: first}) { |(k, v), obj| obj[k] = v unless v.nil? }
  		else
  			raise ArgumentError.new("Invalid arguments")
  		end
  		# _send DEFAULTS.merge(first.is_a?(Hash) ? first : {summary: first, body: others[0]})
  	end
    def self.icon_dirs
      @icon_dirs
    end
  
  	private
  
  	def self.interface
  		@@interface ||= get_interface
  	end
  
  	def self.get_interface
  		bus = DBus::SessionBus.instance
  		obj = bus.service("org.freedesktop.Notifications").object "/org/freedesktop/Notifications"
  		obj.introspect
  		obj["org.freedesktop.Notifications"]
  	end
  
  	def self._send(params)
      icon = params[:icon]
      list = @icon_dirs.map do |dir|
        glob = File.join(dir, icon)
        Dir[glob].map { |fullpath| Icon.new(fullpath) }
      end
      if found = list.flatten.sort.first
        params[:icon] = found.to_s
      end
      $logger.debug("icon: #{params[:icon]}")
  		interface.Notify *DEFAULTS.merge(params).values
  	end
  	
    class Icon
      attr_reader :fullpath
      def initialize(fullpath)
        @fullpath = fullpath
      end
      ICON_REGEX = /(\d+)x\d+/
      def resolution
        @resolution ||= @fullpath[ICON_REGEX, 1].to_i
      end

      def to_s
        fullpath
      end
      def <=>(other)
        result = other.resolution <=> self.resolution
        result = self.fullpath    <=> other.fullpath if result == 0
        result
      end
    end
  end
end
