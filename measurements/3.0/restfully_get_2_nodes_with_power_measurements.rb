# (c) 2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

metric_nodes={}

g5k_login=ENV["USER"]
job_name = "Job for the measurement tutorial created with #{File.basename($0)}"
job_sleeptime= 1800 #s
my_job=nil

root.sites.each do |site| 
  next if site["uid"]=="grenoble"
  begin
    if my_job==nil
      site.jobs(:query => {:user =>g5k_login, :name => job_name}).each do |job|
        if job["name"] == job_name && job['state'] != 'error'
          my_job=job
          my_site=site
          break
        end
      end
    end
  rescue Restfully::HTTP::ServerError => e
    puts "Site #{site["uid"]} unreachable when looking at jobs"
    # print e.message
  end
end

if my_job == nil   
  # we do not have a running job
  # for this tutorial
  puts "Did not find a job named #{job_name}"
  puts "Looking for resources with the proper profile"

  root.sites.each do |site| 
    puts "  looking at reference description of #{site["uid"]}"
    site_pdus={}
    begin
      # we start by mapping all the pdus described for the site
      site.pdus.each do |pdu|
        site_pdus[pdu["uid"]]=pdu["sensors"][0]["power"]["per_outlets"] rescue nil
      end
      
      site.clusters.each do |cluster| 
        puts "    looking at data on cluster #{cluster["uid"]}"
        nodes_status=nil
        cluster.nodes.each do |node| 
          sensors=node["sensors"]
          if sensors != nil
            power_sensor=sensors["power"]
            if power_sensor!= nil
              probes=power_sensor["via"]
              if probes!=nil
                api_probe=probes["api"]
                pdu_info=probes["pdu"]
                if api_probe!=nil && pdu_info!=nil
                  #that node has pdu information in the reference API and 
                  # an entry point in the API to read power measurements 
                  metric_name=api_probe["metric"]
                  if !metric_nodes.has_key?(metric_name)
                    metric_nodes[metric_name]=[]
                  end
                  
                  if pdu_info.is_a?(Array) && pdu_info.size!=1 && pdu_info.first.is_a?(Array)
                    #Array in array we have 2 competing measurement systems
                    puts "    #{node["uid"]} has 2 competing measurement systems. Ignore"
                  else
                    #handle the simple case here where the node is only connected one measurement system
                    if pdu_info.is_a?(Array) && pdu_info.size==1 
                      pdu_info=pdu_info.first
                    end
                    unless pdu_info.is_a?(Array)
                      #handle the simple case here where the node is only connected to one pdu.
                      if site_pdus[pdu_info["uid"]]
                        #the pdu has per outlet measurements, look at availability
                        nodes_status=site.status["nodes"] if nodes_status == nil
                        status=nodes_status[node["uid"]+"."+site["uid"]+".grid5000.fr"]
                        if status["soft"] == "free"
                          if status["reservations"].size == 0 || 
                              (status["reservations"].size > 0 && 
                               Time.at(status["reservations"][0]["scheduled_at"])-Time.now>= job_sleeptime)
                            metric_nodes[metric_name] << { :node => node,
                              :cluster => cluster,
                              :site => site
                            }
                          else
                            puts "      #{node["uid"]} not available long enough"
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
      end
    rescue NoMethodError
      puts "  no pdus entry when describing site #{site["uid"]}"
    end
  end
  puts "Going to elect 2 nodes for our experiment" 
  first_node=metric_nodes["power"].shift if metric_nodes["power"].size > 1
  
  while metric_nodes["power"].size != 0
    second_node=metric_nodes["power"].shift
    if first_node[:site]==second_node[:site]
      break
    end
    first_node=second_node
  end
  if first_node != second_node
    my_site=first_node[:site]
    puts "Attempt to create a job on #{first_node[:site]["uid"]} including #{first_node[:node]["uid"]} and #{second_node[:node]["uid"]}"
    begin
      my_job=my_site.jobs.submit(
                                 :resources => "nodes=2,walltime=00:00:#{job_sleeptime}",
                                 :properties => "network_address in ('#{first_node[:node]["uid"]}.#{my_site["uid"]}.grid5000.fr','#{second_node[:node]["uid"]}.#{my_site["uid"]}.grid5000.fr')",
                                 :command => "sleep 10d",
                                 :types => ["allow_classic_ssh"],
                                 :name => job_name
                                 )
    rescue Restfully::HTTP::ServerError => e
      puts e.message
      [first_node,second_node].each do |elected_node|
        status=elected_node[:node].status(:query => { :reservations_limit => '5'})
        puts "#{status["system_state"]}"
        pp status["reservations"]
      end
      puts "Could node get a job on #{first_node[:node]["uid"]} and #{second_node[:node]["uid"]}. Please retry"
    end
  else
    puts "  did not find 2 available nodes on the same site. Abort"
  end
end

if my_job != nil
  my_job.reload
  if my_job.uri.to_s =~ /sites\/(\w*)\/jobs/
    job_site=$1
  end
  puts "Found job #{my_job["uid"]} at #{job_site} in state #{my_job["state"]}"
  puts " expected to start at #{Time.at(my_job["scheduled_at"])}" if my_job["scheduled_at"] != nil
  puts " expected to end at #{Time.at(my_job["started_at"])+my_job["walltime"].to_i}" if my_job["started_at"] != nil
  wait_time=0
  while my_job.reload['state'] != "running" && wait_time < 30
    sleep 1
    wait_time+=1
    print '.'
  end
  
  if my_job['state'] == "running"
    puts " running on node #{my_job["assigned_nodes"]}. Need to do something with this job"
  end
end  

