require 'cgi'
require 'pp'

module HttpplayerHelper
  # Log level constants that go with dbgp()
  LOG_INFO = 1
  LOG_VERBOSE = 2
  LOG_DEBUG = 3
  
  # this method, for each key specified in options, evaluates the
  # values of the corresponding keys in match_hash, based on the :format
  # and :in expressions, to ensure argument sanity.  It derives and
  # raises appropriate expressions from the match_hash provided data.  
  # :transform is not applied here
  def opt_eval(match_hash, options)
    opt_hash = {}
    match_hash.keys.each do |i| 
      opt_hash.merge!(match_hash[i][:params])
    end
    options.keys.each do |key|
      if opt_hash.has_key?(key)
        if opt_hash[key].has_key?(:format) and options[key].to_s !~ opt_hash[key][:format]
          raise "Invalid format for " + (opt_hash[key].has_key?(:label) ? opt_hash[key][:label] : key).to_s
        end
        if opt_hash[key].has_key?(:in) and !opt_hash[key][:in].include?(options[key])
          raise "Invalid option specified for " + (opt_hash[key].has_key?(:label) ? opt_hash[key][:label] : key).to_s + ".  Must be one of " + opt_hash[key][:in].join(", ")
        end
      end
    end

    opt_hash.keys.reject{|i| !opt_hash[i].has_key?(:mandatory) or !opt_hash[i][:mandatory] == true }.each do |i|
      if !options.has_key?(i) and !opt_hash[i].has_key?(:default)
        raise "Missing required argument " + 
          (opt_hash[i].has_key?(:label) ? opt_hash[i][:label] : key).to_s
      elsif opt_hash[i].has_key?(:default) and options[i].nil?
        options[i] = opt_hash[i][:default]
      end
    end
  end 

  # this method uses our validated options and rules from match_hash to build a hash
  # suitable to be passed to Net::HTTP.post.  :transform is applied here
  def post_params(scenario, path)
    match_hash  = scenario.post_get_opts[path][:params]
    options     = scenario.options
    param_hash = {}
    match_hash.keys.reject{|i| !options.has_key?(i)}.each do |param|
      if HttpplayerScenario.methods.include?((param.to_s + "_transform").to_sym)
        # this can be confusing for Ruby n00bs...  send() allows us to call
        # a method on an object or class identified by a string
        dbgp LOG_VERBOSE, param.to_s + "_transform(#{options[param]})"
        param_hash.merge!(HttpplayerScenario.send(param.to_s + "_transform", scenario, options[param]))
      else
        key = match_hash[param].has_key?(:id) ? match_hash[param][:id].to_s : param.to_s
        #param_hash[key] = CGI.escape(options[param])
        param_hash[key] = options[param]
        if match_hash[param].has_key?(:clone)
          match_hash[param][:clone].each {|p| param_hash[p.to_s] = options[param] }
        end
      end
    end
    return param_hash
  end

  # TODO: Implement this
  def get_params(match_hash, options, params)
    "placeholder string"
  end

  # Parse our command line options based on the rules in the scenario file.  Display
  # help if necessary 
  def optargs_parse(command, post_get_opts)
    opt_args = {}
    options = {}
    opts = OptionParser.new

    opts.banner = "Usage: httpplayer.rb [options] #{command} [options]"

    post_get_opts.keys.each do |path| 
      opt_args.merge!(post_get_opts[path][:params])
    end

    opt_args.keys.reject{|i| !opt_args[i].has_key?(:flags) }.each do |key|
      opts.on(opt_args[key][:flags][0], opt_args[key][:flags][1],
        opt_args[key].has_key?(:label) ? opt_args[key][:label] : key.to_s) do |v|
        options[key] = v
      end
    end
    opts.on("-h", "--help", "Display this help") do |v| 
      options[:help] = v
      puts opts
      exit 0
    end
    opts.order!

    return options
  end

  # method for revealing debugging info based on the value of $verbose
  def dbgp(level, *args)
    if level <= $verbose
      $stderr.print "debug#{level}: "
      $stderr.puts *args
    end
  end
end
