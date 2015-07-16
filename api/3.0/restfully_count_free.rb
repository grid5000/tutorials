# (c) 2012-2015 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

shared_pdu_nodes=[]
pdu_nodes=[]

root.sites.each do |site| 
  site.clusters.each do |cluster| 
    nodes_status=nil
    cluster.nodes.each do |node| 
      sensors=node["sensors"]
      if sensors != nil
        power_sensor=sensors["power"]
        if power_sensor!= nil
          probes=power_sensor["via"]
          if probes!=nil
            api_probe=probes["api"]
            if api_probe!=nil
              nodes_status=site.status["nodes"] if nodes_status == nil
	      status=nodes_status[node["uid"]+"."+site["uid"]+".grid5000.fr"]
              if status["soft"] == "free"
                if status["reservations"].size == 0 || 
                  (status["reservations"].size > 0 && Time.at(status["reservations"][0]["scheduled_at"])-Time.now>= 3600)
                    if api_probe["metric"] == "pdu_shared"
                      shared_pdu_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
                    elsif api_probe["metric"] == "pdu"
                      pdu_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
                    else
                      puts "Do not understand the metric #{api_probe}"
                    end
                else
                  puts "#{node["uid"]} is free but not available long enough"
                end
              end
            end
          end
        end
      end
    end
  end
end

pp "Found #{shared_pdu_nodes.size} nodes running a pdu with a metric for many nodes available for the next hour"
pp "Found #{pdu_nodes.size} nodes running a pdu with a metric for each node and available for the next hour"
