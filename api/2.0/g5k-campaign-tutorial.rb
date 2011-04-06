#!/usr/bin/env ruby

# This tutorial will show you how to use the [g5k-campaign](http://g5k-campaign.gforge.inria.fr) 
# tool to easily build a whole experiment workflow.
#
# This tool is built on the [Restfully](http://github.com/restfully) library, 
# and provide a higher level of abstraction, with support for parallel 
# execution of reservations, deployments, and resource configuration.
#
# You can download the source file for this tutorial from here:
# <https://github.com/grid5000/tutorials/blob/master/api/2.0/g5k-campaign-tutorial.rb>.
#

# Prerequisites
# ---------------------------

# You need to install the `g5k-campaign` library. Assuming you have `Ruby` and
# `rubygems` (1.3.6+) already installed on your system, this can be done with:
#
#     gem install g5k-campaign \
#     --source http://g5k-campaign.gforge.inria.fr/pkg
#
# The library comes with an executable.
# You can get a better feel of what it can do by displaying the usage help:
#
#     g5k-campaign -h
#
# If you do not provide any option, it will launch a campaign using the default parameters, which are:
#
# * submit a 1-hour job on one node of the `rennes` site, and
# * deploy the `lenny-x64-base` environment on the reserved node.
#

# Building your own engine
# ---------------------------

# You can play a little with the various options of the default engine, but
# it is probably more useful to create your own engine that will execute
# specific actions before, after or at any state of your experiment.

# Let's start with a simple engine:

class SimpleCustomEngine < Grid5000::Campaign::Engine

  # We override some of the parameters. 
  # The complete list of options can be found [here](http://g5k-campaign.gforge.inria.fr/Grid5000/Campaign/Engine.html).
  # Note that every parameter given on the command-line will always overwrite those defined in the engine.
  set :environment, "lenny-x64-base"
  set :resources, "nodes=2"
  set :walltime, 7200
  # By default, all the reserved nodes are released when the engine terminates.
  # Here we want to keep the nodes available after the end of the workflow, so that we can still use them.
  set :no_cleanup, true

  # Define an action to execute before reserving resources:
  before :reserve! do |env, *args|
    puts "Executed before reservation!"
    env
  end

  # Define an action to execute after deploying resources:
  after :deployment! do |env, *args|
    puts "Nodes have been deployed: #{env[:nodes].inspect}"
    env
  end

  # Define an action to execute on the installation phase (i.e. after reservation and deployment are done):
  on :install! do |env, *args|
    puts "Installing additional software on the nodes..."
    # We SSH to each node to install additional software.
    # Note that this is a naive approach that only works for small numbers of nodes. 
    env[:nodes].each do |node|
      ssh(node, "root") do |ssh|
        puts ssh.exec!("apt-get update && apt-get install -y ganglia-monitor bonnie++")
        # You can easily copy files on your nodes if you wish.
        # Here we just send a file containing the list of reserved nodes.
        nodes_file = "/tmp/#{env[:job]['uid']}"
        ssh.scp.upload!(StringIO.new(env[:nodes].join("\n")), nodes_file)
      end
    end
    env
  end

  # Define an action to execute after the nodes have been reserved, deployed, and installed:
  on :execute! do |env, *args|
    # Use the :multi option if you want to run SSH commands in parallel. 
    # This is better than sequentially SSHing to nodes, but for large number 
    # of nodes, you should probably connect to the frontend and launch a 
    # [`taktuk`](taktuk.gforge.inria.fr/) process for efficient execution.
    ssh(env[:nodes], "root", :multi => true) do |ssh|
      # Run the `bonnie++` benchmark on each node, and send a random value for a custom metric:
      cmd = %Q{nohup sh -c '(while true; do gmetric --name custom_metric_#{env[:user]} --type uint16 --value $RANDOM; sleep 5; done &) && bonnie++ -u root -d /tmp 1>/dev/null 2>&1' >/dev/null &}
      puts cmd
  
      ssh.exec(cmd)
      ssh.loop
    end
    env
  end

  # Poll the values for two timeseries (our custom metric and `cpu_idle`).
  # Note how we use the `connection` handler, available to any engine, which 
  # is in fact just a `Restfully::Session` object.
  # See the Restfully tutorial for more details.
  after :execute! do |env, *args|
    from = env[:job]['submitted_at']
    resolution = 15
    100.times do
      to = Time.now.to_i-resolution
      ["custom_metric_#{env[:user]}", "cpu_idle"].each do |metric|
        begin
          puts "*** Fetching timeseries for #{metric} metric..."
          connection.root.sites[env[:site].to_sym].metrics[metric.to_sym].
          timeseries(
            :query => {
              :only => env[:nodes].join(","),
              :resolution => resolution,
              :from => from,
              :to => to
            }
          ).reload.each do |timeseries|
            puts timeseries['uid']
            p timeseries['values']
          end
        rescue => e
          puts "Error: #{e.inspect}"
        end
      end
      sleep 10
    end
    env
  end

end

# Running your engines
# ---------------------------

# To execute this engine, you have two solutions. 
# Either you copy the [source file](#section-2) on your machine, and then launch it as follows:
#
#     g5k-campaign -i path/to/file --gateway access.lille.grid5000.fr
# 
# or you directly pass the source file URI to `g5k-campaign` (but you can't make changes):
# 
#     g5k-campaign -i https://github.com/grid5000/tutorials\
#     /raw/master/api/2.0/g5k-campaign-tutorial.rb \
#     --gateway access.lille.grid5000.fr

# Conclusion
# ---------------------------

# This concludes our tutorial, please see the [documentation](http://g5k-campaign.gforge.inria.fr/) and
# [examples](https://gforge.inria.fr/plugins/scmgit/cgi-bin/gitweb.cgi?p=g5k-campaign/g5k-campaign.git;a=tree;f=examples;hb=HEAD) for more advanced usages, 
# including grid reservation, multiple deployments, notifications, etc.