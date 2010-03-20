require 'sinatra'
require 'uki/include_js'
require 'uki/routes'

module Uki
  class Server
    ##
    # Host string.
    
    attr_reader :host
    
    ##
    # Port number.
    
    attr_reader :port
    
    
    def initialize hoststr
      @host, @port  = (hoststr || 'localhost').split(':')
      @port ||= 21119 # 21 u, 11 k, 9 i
    end
    
    def start!
      host, port = @host, @port # otherwise sinatra host and port will hide Server methods
      Sinatra::Application.class_eval do
        begin
          $stderr.puts 'Started uki server at http://%s:%d' % [host, port.to_i]
          detect_rack_handler.run self, :Host => host, :Port => port do |server|
            trap 'INT' do
              server.respond_to?(:stop!) ? server.stop! : server.stop
            end
          end
        rescue Errno::EADDRINUSE
          raise "Port #{port} already in use"
        rescue Errno::EACCES
          raise "Permission Denied on port #{port}"
        end
      end
    end
  end
  
end