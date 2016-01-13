# (c) 2012-2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

metric_nodes={}

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
              metric_name=api_probe["metric"]
              if !metric_nodes.has_key?(metric_name)
                metric_nodes[metric_name]=[]
              end
              metric_nodes[metric_name] << node["uid"]+"."+site["uid"]+".grid5000.fr"
            end
          end
        end
      end
    end
  end
end

metric_nodes.each do |metric,nodes|
  pp "Found #{nodes.size} nodes with a power metric named #{metric}"
end

