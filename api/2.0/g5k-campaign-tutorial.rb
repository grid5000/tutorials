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
    logger.info "Executed before reservation!"
    # For all hooks, we must always return `env`.
    # Otherwise the hook is considered to have failed.
    env
  end

  # Define an action to execute after deploying resources:
  after :deployment! do |env, *args|
    logger.info "[#{env[:site]}] Nodes have been deployed: #{env[:nodes].inspect}"
    env
  end

  # Define an action to execute on the installation phase (i.e. after reservation and deployment are done):
  on :install! do |env, *args|
    logger.info "[#{env[:site]}] Installing additional software on the nodes..."
    # We SSH to each node to install additional software.
    # Note that this is a naive approach that only works for small numbers of nodes.
    env[:nodes].each do |node|
      ssh(node, "root", :timeout => 10) do |ssh|
        output = ssh.exec!("apt-get update && apt-get install -y ganglia-monitor bonnie++")
        logger.debug output
        # You can easily copy files on your nodes if you wish.
        # As an example, here we just send a file containing the list of
        # reserved nodes.
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
    ssh(env[:nodes], "root", :multi => true, :timeout => 10) do |ssh|
      # Run the `bonnie++` benchmark on each node, and publish a custom metric every 5 secs (in a real experiment you'd want to send something else than $RANDOM):
      cmd = %Q{nohup sh -c '(while true; do gmetric --name custom_metric_#{env[:user]} --type uint16 --value $RANDOM; sleep 20; done &) && bonnie++ -u root -d /tmp 1>/dev/null 2>&1' >/dev/null &}
      logger.info "[#{env[:site]}] Executing command: #{cmd}"

      ssh.exec(cmd)
      # In the multi version, we must explicitly tell when the commands are
      # ready to be launched in parallel on all nodes.
      # See <http://net-ssh.github.com/multi/v1/api/index.html> for more info.
      ssh.loop
    end
    env
  end

  # The following is just an example of what we can do once everything is setup and running.
  # Here we'll just poll the values for two timeseries (our custom metric and `cpu_idle`).
  after :execute! do |env, *args|
    from = env[:job]['submitted_at']
    resolution = 15
    10.times do
      to = Time.now.to_i-resolution
      ["custom_metric_#{env[:user]}", "cpu_idle"].each do |metric|
        begin
          logger.info "[#{env[:site]}] Fetching timeseries for #{metric} metric..."
          # Here we use the `connection` handler, available to any engine,
          # to connect to the API.
          #
          # In fact this is just a `Restfully::Session` object.
          # See the Restfully tutorial for more details.
          connection.root.sites[env[:site].to_sym].metrics[metric.to_sym].
          timeseries(
            :query => {
              :only => env[:nodes].join(","),
              :resolution => resolution,
              :from => from,
              :to => to
            }
          ).reload.each do |timeseries|
            logger.info [env[:site], timeseries['uid'], metric].join(" - ")
            logger.info timeseries['values'].inspect
          end
        rescue => e
          logger.warn "[#{env[:site]}] Error when fetching #{metric} metric: #{e.inspect}"
        end
      end
      sleep 15
    end
    env
  end

end

# Running your engines
# ---------------------------

# To execute this engine, you have two solutions.
# Either you copy the [source file](#section-2) on your machine, and then launch it as follows:
#
#     g5k-campaign -i path/to/file --gateway access.lille.grid5000.fr \
#     SimpleCustomEngine
#
# or you directly pass the source file URI to `g5k-campaign` (but you can't make changes):
#
#     g5k-campaign -i https://github.com/grid5000/tutorials\
#     /raw/master/api/2.0/g5k-campaign-tutorial.rb \
#     --gateway access.lille.grid5000.fr \
#     SimpleCustomEngine
#
# As a side-note, if you are in the process of developing or modyfing an
# engine, the `--dev` option of `g5k-campaign` is very useful ;-)
#

# Advanced example
# ---------------------------

# One of the interesting feature of `g5k-campaign` is that you can reuse
# existing engines by creating a subclass. Let's say you'd like to execute the
# previous workflow on more than one site, here is a way to do it.

# Note how we inherit from `SimpleCustomEngine`:
class Grid < SimpleCustomEngine
  set :site, :all # :all or :rennes or [:rennes, :nancy] or...

  before :reserve! do |env, *args|
    logger.info "Reserving nodes on #{site} sites..."
    env
  end

  # Here we change what is done by the default `:reserve!` hook, so that we
  # can launch the reservation process on more than one site at a time.
  on :reserve! do |env, block|
    # We make use of the `how_many?` helper function which returns the number of available nodes on each site (see <http://g5k-campaign.gforge.inria.fr/Grid5000/Campaign/Engine.html#how_many%3F-instance_method>).
    status = how_many?
    logger.info "Status=#{status.inspect}"

    case env[:site].to_s
    when "all"
      sites = status.keys
    when "any"
      # If any site will do, take the one with the most nodes available:
      sites = [status.sort_by{|k,v| v}.last[0]]
    else
      sites = [env[:site]].flatten
    end

    # `g5k-campaign` comes with helper methods for parallel execution (see <http://g5k-campaign.gforge.inria.fr/Grid5000/Campaign/Parallel.html>), whose usage is demonstrated here.
    env[:parallel_reserve!] = parallel(:ignore_thread_exceptions => true)
    envs = []

    sites.each do |uid|
      if status[uid].nil? || status[uid] < 5
        logger.info "Skipped #{uid} since it has only #{status[uid]} nodes that match our requirements."
      else
        new_env = env.merge(:site => uid)
        env[:parallel_reserve!].add(new_env) do |env|
          reserve!(env, &block)
        end
        envs.push(new_env)
      end
    end

    # Master thread must wait for all other threads termination:
    env[:parallel_reserve!].loop!

    # At the end of the whole workflow, automatically display the URL at which
    # a graphical view of the metrics can be seen.
    # Skip the sites where the reservation failed.
    metrics_query = envs.reject{|e| e[:job].nil?}.map do |e|
      [e[:site], e[:job]['uid']].join(":")
    end.join(",")

    logger.info "You can get a graph of your metrics at https://api.grid5000.fr/sid/ui/metrics.html?jobs=#{metrics_query}"

    env
  end

  before :execute! do |env, *args|
    # Call `#wait!` on the parallel object if you want to synchronize all
    # threads at some point. In this example, the execution phase will be
    # launched only after all the other threads are arrived here.
    logger.info "[#{env[:site]}] Waiting for other deployments to finish..."
    env[:parallel_reserve!].wait!
    env
  end

  after :execute! do |env, *args|
    logger.info "[#{env[:site]}] Done!"
    env
  end

end


# Running your engines (with inheritance)
# ---------------------------

# If all your engines are declared in the same file, just use the same command
# as before but replace `SimpleCustomEngine` with `Grid` in the command:
#
#     g5k-campaign -i https://github.com/grid5000/tutorials\
#     /raw/master/api/2.0/g5k-campaign-tutorial.rb \
#     --gateway access.lille.grid5000.fr \
#     Grid
#
# If you have engines declared in more than one file, just use multiple `-i`
# flags to include them all.

# Conclusion
# ---------------------------

# This concludes our tutorial, please see the [documentation](http://g5k-campaign.gforge.inria.fr/) and
# [examples](https://gforge.inria.fr/plugins/scmgit/cgi-bin/gitweb.cgi?p=g5k-campaign/g5k-campaign.git;a=tree;f=examples;hb=HEAD) for more advanced usages,
# including grid reservation, multiple deployments, notifications, etc.