# (c) 2012-2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

job_name = "Running the API all in one Tutorial to learn to reserve nodes #{File.basename($0)}"

#Look for a previously submitted job of the same name
#To avoid submitting submitting twice
my_job=nil
root.sites.each do |site| 
  begin
    if my_job==nil
      site.jobs(:query => {:user =>ENV["USER"], :name => job_name}).each do |job|
        if job["name"] == job_name && job['state'] != "error"
          my_job=job
          break
        end
      end
    end
  rescue Restfully::HTTP::ServerError => e
    puts "Site #{site["uid"]} unreachable"
    # print e.message
  end
end

if my_job==nil
  #we fallback to looking for available resources
  suitable_nodes=[]

  root.sites.each do |site| 
    begin
      site.clusters.each do |cluster| 
        nodes_status=nil
        cluster.nodes.each do |node| 
          if node["storage_devices"].size == 1
            # there is at least one interesting node in this site
            # get the status of nodes
            nodes_status=site.status["nodes"] if nodes_status == nil
            status=nodes_status[node["uid"]+"."+site["uid"]+".grid5000.fr"]
            if status["soft"] == "free"
              if status["reservations"].size == 0 || 
                  (status["reservations"].size > 0 && Time.at(status["reservations"][0]["scheduled_at"])-Time.now>= 3600)
                suitable_nodes << { :node => node,
                        :cluster => cluster,
                        :site => site
                }
              else
                puts "#{node["uid"]} is free but not available long enough"
              end
            end
          end
        end
      end
    rescue Restfully::HTTP::ServerError => e
      puts "Could not access information from #{site["uid"]}"
    end
  end
    
  elected_node= suitable_nodes.pop

  if elected_node != nil
    puts "Attempt to create a job on #{elected_node[:node]["uid"]}.#{elected_node[:site]["uid"]}.grid5000.fr"
    begin
      my_job=elected_node[:site].jobs.submit(
                                             :resources => "nodes=1,walltime=00:30:00",
                                             :properties => "network_address in ('#{elected_node[:node]["uid"]}.#{elected_node[:site]["uid"]}.grid5000.fr')",
                                             :command => "sleep 3600",
                                             :types => ["allow_classic_ssh"],
                                             :name => job_name
                                             )
    rescue Restfully::HTTP::ServerError => e
      status=elected_node[:node].status(:query => { :reservations_limit => '5'})
      puts e.message
      puts "#{status["system_state"]}"
      pp status["reservations"]
      puts "Could node get a job on #{elected_node[:node]["uid"]}. Please retry on another node"
    end
  end
end

if my_job != nil
  my_job.reload
  puts "Found job #{my_job["uid"]} in state #{my_job["state"]}"
  puts " expected to start at #{Time.at(my_job["scheduled_at"])}" if my_job["scheduled_at"] != nil

  wait_time=0
  while my_job.reload['state'] != "running" && wait_time < 30
    sleep 1
    wait_time+=1
    print '.'
  end

  if my_job['state'] == "running"
    puts "running on node #{my_job["assigned_nodes"]}. Need to do something with this job"
  end
end

