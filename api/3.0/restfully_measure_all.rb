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
              metric_name=api_probe["metric"]
              print "looking for #{metric_name} "
              metric=site.metrics[metric_name.to_sym]
              if metric ==nil
                puts "metrology API does not include metric #{metric_name} for #{node["uid"]} as reported by the reference API - please report the bug"
              else
                metrics= site.metrics[metric_name.to_sym].timeseries(:query => {:resolution => 15, :from => Time.now.to_i-600*1 })[node["uid"].to_sym]["values"]
                metrics.compact!
                puts "#{node["uid"]} last seen consumming #{metrics[metrics.size-1]} W (#{metric_name})"
              end
            end
          end
        end
      end
    end
  end
end


