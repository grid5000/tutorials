# (c) 2012-2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

suitable_nodes=[]

root.sites.each do |site| 
  site.clusters.each do |cluster| 
    cluster.nodes.each do |node| 
      if node["storage_devices"].size == 1
        suitable_nodes << node["uid"]+"."+site["uid"]+".grid5000.fr"
      end
    end
  end
end

puts "Found #{suitable_nodes.size} nodes with only one local storage device"

