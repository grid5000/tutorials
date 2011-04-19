#!/usr/bin/env ruby

# This tutorial will show you how to reserve nodes and deploy a specific
# environment on every site of Grid'5000 (granted there are nodes available), 
# using the [Restfully](http://github.com/grid5000/restfully) Ruby library.
#
# You can download the source file for this tutorial from here: <https://github.com/grid5000/tutorials/blob/master/api/2.0/restfully-tutorial.rb>.
#
# As `cURL`, `Restfully` can use a configuration file so that you don't need
# to enter your credentials by hand. 
# Copy-paste the following in a terminal:
#
#     mkdir ~/.restfully
#     cat <<EOF > ~/.restfully/api.grid5000.fr.yml
#     base_uri: https://api.grid5000.fr/2.0/grid5000
#     username: "your-grid5000-login"
#     password: "your-grid5000-password"
#     EOF
#     chmod 600 ~/.restfully/api.grid5000.fr.yml
# 
# Then edit the `~/.restfully/api.grid5000.fr.yml` file to enter the correct
# information for `username` and `password`.
#
# Once you've done that, you need to install the following Ruby gems:
#
#     gem install restfully net-ssh-gateway
#
# And you should be ready to go! From your local machine, you can run the 
# script with:
#
#     curl -k https://github.com/grid5000/tutorials/raw/master/\
#     api/2.0/restfully-tutorial.rb | ruby
#
# Note that you can also use Restfully in an interactive manner:
# 
#     restfully -c ~/.restfully/api.grid5000.fr.yml
#
# Below you will find the annotated source code for the script.

# Prerequisites
# ---------------------------

# Here are the libraries that this script uses:
require 'rubygems'        # or: export RUBYOPT="-rubygems"
require 'restfully'       # gem install restfully
require 'net/ssh/gateway' # gem install net-ssh-gateway
require 'json'            # gem install json
require 'yaml'

# Initialization
# ---------------------------

# Declare a logger to log messages:
LOGGER       = Logger.new(STDERR)
LOGGER.level = Logger::INFO

# Load the Restfully configuration file that contains your API credentials.
CONFIG = YAML.load_file(File.expand_path("~/.restfully/api.grid5000.fr.yml"))

# Attempts to find a public SSH key in your home directory.
PUBLIC_KEY       = Dir[File.expand_path("~/.ssh/*.pub")][0]
fail "No public key available in ~/.ssh !" if PUBLIC_KEY.nil?

# Attempts to find the corresponding private part of the SSH key.
PRIVATE_KEY  = File.expand_path("~/.ssh/#{File.basename(PUBLIC_KEY, ".pub")}")
fail "No private key corresponding to the public key available in ~/.ssh !" unless File.file?(PRIVATE_KEY)

LOGGER.info "Using the SSH public key located at: #{PUBLIC_KEY.inspect}"

# Create an SSH gateway to access the Grid'5000 machines from outside.
# Note that this is not needed if you operate from a Grid'5000 frontend.
GATEWAY      = Net::SSH::Gateway.new('access.lille.grid5000.fr', CONFIG["username"])

# Structures to keep track of the jobs and deployments we submit.
JOBS         = []
DEPLOYMENTS  = []

# We don't want to wait forever, right?
TIMEOUT_JOB  = 2*60 # 2 minutes
TIMEOUT_DEPLOYMENT = 15*60 # 15 minutes

# The command to run on each node after they are deployed:
COMMAND = "hostname"

# Be a good citizen and delete everything when an error or interruption occurs:
def cleanup!
  LOGGER.warn "Received cleanup request, killing all jobs and deployments..."
  DEPLOYMENTS.each{|deployment| deployment.delete}
  JOBS.each{|job| job.delete}
end

# Cleanup everything upon receiving SIGINT or SIGTERM:
%w{INT TERM}.each do |signal|
  Signal.trap(signal){ 
    cleanup! 
    exit(1)
  }
end

# Main part of the code
# ---------------------------
begin
  # Open a session to the API:
  Restfully::Session.new(
    :base_uri => CONFIG['base_uri'],
    :username => CONFIG['username'],
    :password => CONFIG['password'],
    :logger => LOGGER
  ) do |root, session|
    # Loop over each Grid'5000 site and attempts to reserve nodes:
    root.sites.each do |site|
      # For each Grid'5000 site, fetch its status
      # and submit a job if there is at least one node available.
      if site.status.find{ |node|
        node['system_state'] == 'free' && node['hardware_state'] == 'alive'
      } then
        # The OAR scheduler expects a program to be run.
        # In our case we will deploy our own environment
        # and execute a script later,
        # therefore we just tell him to sleep for the duration of the job.
        new_job = site.jobs.submit(
          :resources => "nodes=1,walltime=00:30:00",
          :command => "sleep 1800",
          :types => ["deploy"],
          :name => "API Main Practical"
        ) rescue nil
        JOBS.push(new_job) unless new_job.nil?
      else
        session.logger.info "Skipped #{site['uid']}. Not enough free nodes."
      end
    end

    if JOBS.empty?
      session.logger.warn "No jobs, exiting..."
      exit(0)
    end

    # Once all the jobs have been submitted, we wait until all are running.
    begin
      Timeout.timeout(TIMEOUT_JOB) do
        until JOBS.all?{|job|
          job.reload['state'] == 'running'
        } do
          session.logger.info "Some jobs are not running. Waiting before checking again..."
          sleep TIMEOUT_JOB/30
        end
      end
    rescue Timeout::Error => e
      session.logger.warn "One of the jobs is still not running, it will be discarded."
    end

    # Deploy a specific image on all of our reserved nodes
    JOBS.each do |job|
      next if job.reload['state'] != 'running'
      new_deployment = job.parent.deployments.submit(
        :environment => "lenny-x64-base",
        :nodes => job['assigned_nodes'],
        :key => File.read(PUBLIC_KEY)
      ) rescue nil
      DEPLOYMENTS.push(new_deployment) unless new_deployment.nil?
    end

    # Exit if no deployments
    if DEPLOYMENTS.empty?
      session.logger.warn "No deployments, exiting..."
      cleanup!
      exit(0)
    end

    # Wait until all deployments are no longer processing.
    begin
      Timeout.timeout(TIMEOUT_DEPLOYMENT) do
        until DEPLOYMENTS.all?{ |deployment|
          deployment.reload['status'] != 'processing'
        } do
          session.logger.info "Some deployments are not terminated. Waiting before checking again..."
          sleep TIMEOUT_DEPLOYMENT/30
        end
      end
    rescue Timeout::Error => e
      session.logger.warn "One of the deployments is still not terminated, it will be discarded."
    end

    # Connect to all our nodes an execute a command on each one:
    DEPLOYMENTS.each do |deployment|
      next if deployment.reload['status'] != 'terminated'

      # Connect as `root` to the nodes, via the specified gateway.
      # What follows is a naive approach that works for small numbers of nodes.
      deployment["nodes"].each do |host|
        puts "Connecting to #{host} and running #{COMMAND.inspect}..."
        GATEWAY.ssh(host, "root",
          :keys => [PRIVATE_KEY], :auth_methods => ["publickey"]
        ) do |ssh|
          puts ssh.exec!(COMMAND)
        end
      end
    end
    
  end
# Rescue and display any exception that could be raised:
rescue StandardError => e
  LOGGER.warn "Catched unexpected exception #{e.class.name}: #{e.message} - #{e.backtrace.join("\n")}"
  cleanup!
  exit(1)
end
