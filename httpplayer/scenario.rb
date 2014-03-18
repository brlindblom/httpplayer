require 'net/http'
require 'net/https'
require 'httpplayer/helper'
include HttpplayerHelper

class HttpplayerScenario
  attr_accessor :options, :opt_match, :post_get_opts, :password, :user, :verbose, :url, 
                :config_path, :dryrun

  # Yep... we're going to create an class method called scenario that will be
  # "injected" from a dynamic require when we initialize.  I'll try to figure out
  # a cleaner way to do this since a class method makes no sense
  class << self
    attr_accessor :scenario
  end

  def initialize(command, config_path)
    # This will bring in our scenario file based on the command options: config_path and command
    require "#{config_path}/#{command}"

    # get the necessary little bits
    self.url = HttpplayerScenario.scenario[:url]
    self.post_get_opts = HttpplayerScenario.scenario[:paths]

    # here's where we parse our command options against our scenario file
    self.options = optargs_parse command, self.post_get_opts

    # here's where we santiy-check our command options and supplied values against the scenario file
    opt_eval self.post_get_opts, self.options

    # let the block set stuff for us
    yield self if block_given?
  end

  # Walk through the scenario
  def play
    # Establish the ordering of our URI paths using a topological sort, to handle the
    # dependency chain
    l = []
    edges = {}

    # calculate our edges.  We'll treat the dependencies as an acyclical graph
    # for each path...
    self.post_get_opts.keys.each do |node|
      # this list is nodes that point to us
      edges[node] = []

      # for each path that is NOT the current path (every other path)
      self.post_get_opts.keys.reject{|i| i == node }.each do |dep|
        # if this path depends on node, add him as an edge  
        if self.post_get_opts[dep].has_key?(:depends) and self.post_get_opts[dep][:depends] == node
          edges[node] << dep
        end
      end
    end

    # lets run a topsort on the edge graph
    # build our "queue" with nodes to which other nodes do not point
    queue = self.post_get_opts.keys.reject{|i| !edges[i].empty? }

    while !queue.empty?
      obj = queue.pop
      l.push(obj)

      # for nodes with edges
      edges.keys.reject{|i| edges[i].empty? }.each do |node|
        if edges[node].include?(obj)
          edges[node].delete(obj)
          queue.push(node)
        end
      end
    end

    if !edges.keys.reject{|i| edges[i].empty?}.empty?
      raise "Dependency resolution error with CGI path dependencies"
    end

    dbgp LOG_VERBOSE, "Traversing paths: #{l.reverse.to_s}"

    # Our topological sort gives us our list in reverse.  Each path
    # will be played against the specified server, with appropriate get/post parameters
    # derived from the provided command line arguments
    params = {}
    l.reverse.each do |path|
      # do the right HTTP method based on what's in the scenario file
      dbgp LOG_INFO, "URI #{self.url}"
      u = URI.parse(self.url + path)

      # compile our command line options into a nice url-encoded hash for use with POST/GEt
      params.merge! post_params(self,path)

      if self.dryrun
        puts "#{self.post_get_opts[path][:method].to_s.upcase} #{u.path} - " + params.pretty_inspect.to_s
      else
        dbgp LOG_INFO, "#{self.post_get_opts[path][:method].to_s.upcase} #{u.path}" 
        dbgp LOG_VERBOSE, "Params: " + params.pretty_inspect.to_s

        case self.post_get_opts[path][:method]
        when :get # TODO: Full implementation of the :get method
          res = Net::HTTP.start(URI.parse(self.url)) do |http|
            http.get(path + "?" + params.keys.map{|i| i.to_s + "=" + params[i]}.join("&"))
          end
          cookie = res.response['set-cookie'].split('; ')[0]
        when :post
          http = Net::HTTP.new(u.host, u.port)
          http.use_ssl = u.scheme == 'https'
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE

          request = Net::HTTP::Post.new(u.request_uri)

          request.set_form_data params
          request.basic_auth self.user, self.password
          request['cookie'] = cookie if defined?(cookie)

          response = http.request(request)

          case response
          when Net::HTTPSuccess, Net::HTTPRedirection
            errors = response.body.to_s.match(self.post_get_opts[path][:bad_out])
            if !errors.nil?
              puts response.body.to_s if self.post_get_opts[path][:print_response]
              puts "================================="
              puts errors[1]
              break
            else
              dbgp LOG_INFO, "POST #{path} success"
              puts response.body.to_s if self.post_get_opts[path][:print_response]
              f_inputs = self.post_get_opts[path][:parse_and_forward_inputs]
              if !f_inputs.nil?
                response.body.scan(/<INPUT.*/) do |match|
                  f_name = f_value = ""
                  resp = match.split(" ")
                  resp.each do |field|
                    case field
                    when /^NAME=.*/
                      f_name = field.split("=")[1]
                    when /^VALUE=.*/
                      f_value = field.split("=")[1].gsub(/>$/,"")
                    end
                  end
                  if (f_inputs.is_a? Array and f_inputs.include? f_name.gsub(/"/,"")) or !f_inputs.is_a? Array
                    params[f_name.gsub(/"/,"").to_sym] = f_value.gsub(/"/,"")
                  end
                end
              end
            end
            #cookie = response.get_fields('set-cookie').split('; ')[0]
          when Net::HTTPUnauthorized
            puts "Bad credentials, buddy"
            break
          else
            puts response.body.to_s
          end
        end
      end
    end
  end
end
