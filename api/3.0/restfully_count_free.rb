# (c) 2012-2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

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
              suitable_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
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

puts "Found #{suitable_nodes.size} nodes with only one local storage device available for the next hour"
