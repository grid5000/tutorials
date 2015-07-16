# (c) 2012-2015 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

shared_pdu_nodes=[]
pdu_nodes=[]

root.sites.each do |site| 
  site.clusters.each do |cluster| 
    cluster.nodes.each do |node| 
      sensors=node["sensors"]
      if sensors != nil
        power_sensor=sensors["power"]
        if power_sensor!= nil
          probes=power_sensor["via"]
          if probes!=nil
            api_probe=probes["api"]
            if api_probe!=nil
              if api_probe["metric"] == "pdu_shared"
                shared_pdu_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
              elsif api_probe["metric"] == "pdu"
                pdu_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
              else
                puts "Do not understand the metric #{api_probe}"
              end
            end
          end
        end
      end
    end
  end
end

pp "Found #{shared_pdu_nodes.size} nodes running a pdu with a metric for many nodes"
pp "Found #{pdu_nodes.size} nodes running a pdu with a metric for each node"

