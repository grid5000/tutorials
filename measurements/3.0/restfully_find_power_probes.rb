# (c) 2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

metric_nodes={}
pdu_nodes={}

root.sites.each do |site| 
  puts "looking at data at #{site["uid"]}"
  site_pdus={}
  begin
    # we start by mapping all the pdus described for the site
    site.pdus.each do |pdu|
      site_pdus[pdu["uid"]]=pdu["sensors"][0]["power"]["per_outlets"] rescue nil
    end
    
    site.clusters.each do |cluster| 
      puts "  looking at data on cluster #{cluster["uid"]}"
      cluster.nodes.each do |node| 
        api_probe=node["sensors"]["power"]["via"]["api"] rescue nil
        pdu_info=node["sensors"]["power"]["via"]["pdu"] rescue nil
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
                #the pdu has per outlet measurments
                metric_nodes[metric_name] << node["uid"]+"."+site["uid"]+".grid5000.fr"
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

metric_nodes.each do |metric,nodes|
  pp "Found #{nodes.size} nodes with a power metric named #{metric}, connected to a pdu with per_outlet measurements"
end

