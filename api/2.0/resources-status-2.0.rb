#!/usr/bin/env ruby

require 'optparse'
require 'restfully'
require 'yaml'
require 'time'

# The config file should contain your login, password and base_uri of the API:
# grid5000:
#   username: LOGIN
#   password: PASSWORD
#   base_uri: https://api.grid5000.fr/2.0/grid5000
CONFIG = YAML.load_file(File.expand_path("~/.restclient"))['grid5000']

# Initialize variables (sites, walltime, start_timeetc.)
sites = [{:name => :rennes}, {:name => :nancy}]
walltime = 3600

# The start time should be in epoch time. You can use any format parsable by ruby.
# - Time.now.to_i
# - Time.parse("YYYY/MM/DD HH/mm/SS")
# - etc.
start_time = Time.now.to_i
stop_time = start_time + walltime

# Ignore best effort jobs and check that there is no job between start and stop date
def filter_reservations(reservations, start_time, stop_time)
  reservations.select do |r|
    r['start_time'] < stop_time && r['start_time'] + r['walltime'] > start_time && r['queue'] != 'besteffort'
  end
end

Restfully::Session.new(
  :username => CONFIG['username'],
  :password => CONFIG['password'],
  :base_uri => CONFIG['base_uri']
) do |grid, session|
  sites.each do |site|
    # Initialize the list of nodes that will save the status of the nodes
    site[:all_nodes] = []
    site[:dead_nodes] = []
    site[:avail_nodes] = []

    # Get the state of of nodes of each site (ask to get 100 reservations per node, default is very low)
    grid.sites[site[:name]].status(:query => { :reservations_limit => '100'}).each do |node|
      site[:all_nodes] << node
      site[:dead_nodes] << node   if node['hardware_state'] == 'dead'
      site[:avail_nodes] << node  if filter_reservations(node['reservations'], start_time, stop_time).empty? && node['hardware_state'] != 'dead'
    end

  end
end

# Display the results
sites.each do |site|
  puts "#{site[:name]}:
  nodes: (max/dead/fully_avail): #{site[:all_nodes].length}/#{site[:dead_nodes].length}/#{site[:avail_nodes].length}"
end
