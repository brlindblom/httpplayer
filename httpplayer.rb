#!/usr/bin/env ruby
#
# Maintainer      : Brian Lindblom
# Description     : This tool allows someone to create scenario files to interface with remote web 
#                   services, translating command line options and their values to HTTP POST/GET 
#                   parameters to pass to the web service.  This allows someone to very EASILY 
#                   implement command line tools for CGI-based applications
# Assumptions     : rubygems, highline, optparse, cgi
#
# Created 20140313 lindblom
#

require 'rubygems'
require 'highline/import'
require 'optparse'
require 'httpplayer/scenario'
require 'cgi'

$verbose = 0

options = { :url => "http://example.com", :config_path => "/etc/httpplayer" }

# Global options, before our subcommand
global = OptionParser.new do |opts|
  opts.banner = "Usage: httpplayer.rb [options] [subcommand [options]]"
  opts.on("-v", "--verbose", "Run with extra output turned on") { |v| $verbose += 1 } 
  opts.on("-c", "--cfgpath [CFGPATH]", "Specify runtime configuration path") { |v| options[:config_path] = v } 
  opts.on("-U", "--user [USER]", "Netreg username") { |v| options[:http_user] = v }
  opts.on("-d", "--dryrun", "Dry run.  Just print out the requests to be made") { |v| options[:dry_run] = v }
  opts.on("-h", "--help", "Display this help") do |v| 
    puts opts
    subcommands = Dir.entries(options[:config_path]).reject{|i| [".",".."].include?(i)}.map{|i| i.gsub(/\.rb$/,"") }
    puts "\n[subcommands] are " + subcommands.join(", ")
    puts "\nHelp for subcommands can be access by adding -h anywhere after the subcommand"
    exit 0
  end   
end

if ARGV.length == 0
  puts global.help
  subcommands = Dir.entries(options[:config_path]).reject{|i| [".",".."].include?(i)}.map{|i| i.gsub(/\.rb$/,"") }
  puts "\n[subcommands] are " + subcommands.join(", ")
  puts "\nHelp for subcommands can be access by adding -h anywhere after the subcommand"
  exit 0
end

global.order!

command = ARGV.shift

subcommands = Dir.entries(options[:config_path]).reject{|i| [".",".."].include?(i)}.map{|i| i.gsub(/\.rb$/,"") }

if command.nil? or !subcommands.include?(command)
  puts global.help
  puts "\n[subcommands] are " + subcommands.join(", ")
  puts "\nHelp for subcommands can be access by adding -h anywhere after the subcommand"
  exit 0
end

# Build our HttpplayerScenario object based on the arguments and the scenario file
begin
  action = HttpplayerScenario.new(command, options[:config_path]) do |i|
    i.user = options[:http_user]
    i.password = ask("HTTP Password: ") {|q| q.echo = "*" }
    i.dryrun = options[:dry_run]
  end
rescue Exception => e
  puts e.message
  exit 1
end

raise OptionParser::MissingArgument, "HTTP Username" if options[:http_user].nil?

# Run the scenario
#begin
  action.play
#rescue Exception => e
#  puts e.message
#  exit 1
#end
