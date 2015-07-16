# (c) 2012-2015 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

job_name = "Looking at power consumption with metrology API with #{File.basename($0)}"

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
  pdu_nodes={}

  root.sites.each do |site| 
    site.clusters.each do |cluster| 
      node_status=nil
      cluster.nodes.each do |node| 
        sensors=node["sensors"]
        if sensors != nil
          power_sensor=sensors["power"]
          if power_sensor!= nil
            probes=power_sensor["via"]
            if probes!=nil
              api_probe=probes["api"]
              if api_probe!=nil
                node_status=site.status["nodes"] if node_status == nil
        	status=node_status[node["uid"]+"."+site["uid"]+".grid5000.fr"]
                if status["soft"] == "free"
                  if status["reservations"].size > 0
                    if Time.at(status["reservations"][0]["scheduled_at"])-Time.now>= 1800 
                       pdu_nodes[api_probe["metric"]] = [] if ! pdu_nodes.has_key?(api_probe["metric"])
                      pdu_nodes[api_probe["metric"]] << { :node => node,
                        :cluster => cluster,
                        :site => site
                      }
                    else
                      puts "#{node["uid"]} not available"
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  elected_node= if pdu_nodes["pdu"] != nil
                pdu_nodes["pdu"].pop
              else
                pdu_nodes["pdu_shared"].pop if pdu_nodes["pdu_shared"] != nil
              end
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

