# (c) 2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

def update_pdu_nodes(pdu_nodes,pdu_probe_name,node,site)
  if pdu_nodes.has_key?(pdu_probe_name)
    #this probe is connected to more than one node
    if pdu_nodes[pdu_probe_name][:type]=="node"
      first_node=pdu_nodes[pdu_probe_name]
      pdu_nodes[pdu_probe_name]={
        :type => "multiple",
        :endpoints => []
      }
      pdu_nodes[pdu_probe_name][:endpoints] << first_node
    end
    pdu_nodes[pdu_probe_name][:endpoints] << { 
      :type => "node",
      :uid => node["uid"],
      :fqdn => node["uid"]+"."+site["uid"]+".grid5000.fr" }
  else
    pdu_nodes[pdu_probe_name]={ 
      :type => "node",
      :uid => node["uid"],
      :fqdn => node["uid"]+"."+site["uid"]+".grid5000.fr" }
  end
end

def compact_ids(ids)
  #take an array of id, and represents them in a compact way
  # [1] to '1'
  # [1,2,3] to '[1-3]'
  # [1,2,3,5] to '[1-4,5]
  ids.uniq!
  ids.sort!
  continuous_ids=[]
  initial_id=current_id=ids.shift
  ids.each do |id|
    if id==current_id+1
      current_id=id
    else
      if initial_id != current_id
        continuous_ids << "#{initial_id}-#{current_id}"
      else
        continuous_ids << current_id.to_s
      end
      initial_id=current_id=id
    end
  end
  if initial_id != current_id
    continuous_ids << "#{initial_id}-#{current_id}"
  else
    continuous_ids << current_id.to_s
  end
  compact_str=""
  if continuous_ids.size > 1
    compact_str="[#{continuous_ids*','}]"
  elsif continuous_ids.first =~ /\-/
    compact_str="[#{continuous_ids.first}]"
  else
    compact_str=continuous_ids.first
  end
  compact_str
end

def compact_nodes(all_nodes)
  nodes=all_nodes.sort do |u,v| 
    u_uid=u.split('.')[0]
    u_cluster=u_uid.split('-')[0]
    u_index=u_uid.split('-')[1].to_i
    v_uid=v.split('.')[0]
    v_cluster=v_uid.split('-')[0]
    v_index=v_uid.split('-')[1].to_i
    if u_cluster != v_cluster
      u_cluster <=> v_cluster
    elsif u_index != v_index
      u_index <=> v_index
    else
      u <=> v
    end
  end
  if nodes.size > 1
    clusters=[]
    first_node=nodes.shift
    node_components=first_node.split('.')
    first_uid=node_components.shift
    if node_components.size > 0
      suffix=".#{node_components*'.'}"
    else
      suffix=""
    end
    current_cluster=first_uid.split('-')[0]
    initial_index=current_index=first_uid.split('-')[1] rescue nil
    cluster_indexes = [initial_index.to_i]
    nodes.each do |node|
      node_components=node.split('.')
      node_uid=node_components.shift
      if node_components.size > 0
        suffix=".#{node_components*'.'}"
      else
        suffix=""
      end
      node_cluster=node_uid.split('-')[0]
      if current_cluster==node_cluster
        node_index=node_uid.split('-')[1]
        cluster_indexes << node_index.to_i
      else
        clusters << "#{current_cluster}-#{compact_ids(cluster_indexes)}#{suffix}"
        current_cluster=node_cluster
        initial_index=current_index=node_uid.split('-')[1]
        cluster_indexes = [initial_index.to_i]
      end
    end
    clusters << "#{current_cluster}-#{compact_ids(cluster_indexes)}#{suffix}"
  else
    nodes.first
  end
  clusters*","
end


def get_probe_name(site_pdus,site_errors,pdu_info,site)
  plug_name=pdu_info["port"]||pdu_info["measure"]||"0"
  plug_name=plug_name.to_s if plug_name.is_a?(Fixnum)
  if pdu_info["uid"] =~ /grid5000\.fr/
    pdu_probe_name=plug_name+"."+pdu_info["uid"]
    if !site_pdus[site["uid"]].has_key?(pdu_info["uid"]) && 
        site_pdus[site["uid"]].has_key?(pdu_info["uid"].split('.')[0])
      site_errors[site["uid"]] << "pdu #{pdu_info["uid"].split('.')[0]} is referenced on nodes with #{pdu_info["uid"]}"
    end
  else
    pdu_probe_name=plug_name+"."+pdu_info["uid"]+"."+site["uid"]+".grid5000.fr"  
  end
  pdu_probe_name
end

api_metric_nodes={}
power_nodes=[]
pdu_nodes={}
site_pdus={}
site_errors={}
monitoring_nodes={}
node_power_connectivity={"per_outlet"=>[],"unknown"=>[],"shared"=>[]}
sites_with_power_in_metrology_api=[]
sites_with_power_in_reference_api=[]
nodes_site={}
nodes_index={}

puts "***** Gathering information ***************"

root.sites.each do |site| 
  if ENV.has_key?('SITE')
    next unless site["uid"]==ENV['SITE']
  end
  puts "looking at reference API description for #{site["uid"]}"
  site_pdus[site["uid"]]={}
  site_errors[site["uid"]]=[]
  begin
    site.pdus.each do |pdu|
      site_pdus[site["uid"]][pdu["uid"]]=pdu["sensors"][0]["power"]["per_outlets"] rescue nil
    end
  rescue NoMethodError
    site_errors[site["uid"]] << "No pdus entry when describing site"
  end
  site.clusters.each do |cluster| 
  # next unless cluster["uid"]=="graphene"
    puts "  looking at data for cluster #{cluster["uid"]}"
    cluster.nodes.each do |node| 
      nodes_index[node["uid"]]=node
      nodes_site[node["uid"]]=site["uid"]
      monitoring=node["monitoring"]["wattmeter"] rescue nil
      if monitoring.nil?
        puts "#{node["uid"]} has no ['monitoring']['wattmeter'] entry"
        #site_errors[site["uid"]] << "#{node["uid"]} has no ['monitoring']['wattmeter'] entry"
      else
        monitoring_nodes[monitoring]= [] unless monitoring_nodes.has_key?(monitoring)
        monitoring_nodes[monitoring] << node["uid"]
      end
      sensors=node["sensors"]
      if sensors != nil
        power_sensor=sensors["power"]
        if power_sensor!= nil
          probes=power_sensor["via"]
          if probes!=nil
            api_probe=probes["api"]
            if api_probe!=nil
              metric_name=api_probe["metric"]
              sites_with_power_in_reference_api << site["uid"] if metric_name=="power"
              if !api_metric_nodes.has_key?(metric_name)
                api_metric_nodes[metric_name]=[]
              end
              api_metric_nodes[metric_name] << node["uid"]
            end
            pdu_info=probes["pdu"]
            unless pdu_info.nil?
              if pdu_info.is_a?(Array) && pdu_info.size!=1 && pdu_info.first.is_a?(Array)
                #Array in array we have 2 competing measurement systems
                site_errors[site["uid"]] << "#{node["uid"]} has 2 competing measurement systems. Not handled"
              else
                #handle the simple case here where the node is only connected one measurement system
                if pdu_info.is_a?(Array) && pdu_info.size==1 
                  pdu_info=pdu_info.first
                end
                unless pdu_info.is_a?(Array)
                  #handle the simple case here where the node is only connected to one pdu.
                  pdu_probe_name=get_probe_name(site_pdus, site_errors, pdu_info, site)
                  update_pdu_nodes(pdu_nodes, pdu_probe_name, node, site)
                  if site_pdus[site["uid"]][pdu_info["uid"]].nil?
                    site_errors[site["uid"]] << "No per_outlet info in #{site["uid"]} for #{pdu_info["uid"]}"
                    node_power_connectivity["unknown"] << node
                  elsif site_pdus[site["uid"]][pdu_info["uid"]]
                    node_power_connectivity["per_outlet"] << node
                  else
                    node_power_connectivity["shared"] << node
                  end
                else
                  per_outlet=true
                  pdu_info.each do |a_pdu_info|
                    pdu_probe_name=get_probe_name(site_pdus, site_errors, a_pdu_info, site)
                    update_pdu_nodes(pdu_nodes, pdu_probe_name, node, site)
                    per_outlet=per_outlet && site_pdus[site["uid"]][a_pdu_info["uid"]] rescue nil
                  end
                  if per_outlet.nil?
                    node_power_connectivity["unknown"] << node
                  elsif per_outlet
                    node_power_connectivity["per_outlet"] << node
                  else
                    node_power_connectivity["shared"] << node
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  puts "Looking for metric named 'power' at #{site["uid"]}"
  old_retry=session.config.options[:retry_on_error]
  session.config.options[:retry_on_error]=0
  begin
    power_metric=site.metrics[:power]
    if !power_metric.nil?
      sites_with_power_in_metrology_api << site["uid"]
      power_metric_probes=power_metric["available_on"]
      if !power_metric_probes.nil?
        power_metric_probes.each do |probe_name|
          if pdu_nodes.has_key?(probe_name)
            if  pdu_nodes[probe_name][:type]=="node"
              power_nodes << pdu_nodes[probe_name][:uid]
            elsif pdu_nodes[probe_name][:type]=="multiple"
              pdu_nodes[probe_name][:endpoints].each do |endpoint|
                power_nodes << endpoint[:uid]
              end
            end
          else
            site_errors[site["uid"]] << "Could not find node(s) associated to power probe #{probe_name}"
          end
        end
      end
    end
  rescue Exception => e
    puts "Did not find metrics named 'power' at #{site["uid"]} because of exception #{e.to_s[0..40]}... (OK if kwapi not installed)"
  end
  session.config.options[:retry_on_error]=old_retry
end

puts "\n\n****** Analysing the gathered information *************"

puts "\nPower sensor description of nodes through ['sensors']['power']['via']['api']"
nodes_with_metrics=[]
api_metric_nodes.each do |metric,nodes|
  nodes.uniq!
  nodes_with_metrics+=nodes.map{|n| n.split('.')[0]}
  puts "  Found #{nodes.size} nodes with a power metric named '#{metric}' in the API (#{compact_nodes(nodes)})" if nodes.size > 0
end


puts "\nMonitoring information through ['monitoring']['wattmeter']"
puts "(see https://www.grid5000.fr/mediawiki/index.php/TechTeam:Reference_Repository#Monitoring_section for meaning)"
monitoring_nodes.each do |value, nodes|
  puts "  Found #{nodes.size} nodes with '#{value}' as power monitoring property advertised by ['monitoring']['wattmeter'] for OAR (nodes #{compact_nodes(nodes)})" 
end

puts "\nInformation from the reference API connecting pdus and ['sensors']['power']['via']['pdu'] information"
probes_of_one_node=pdu_nodes.select {|probe,description| description[:type]=="node"}
probes_of_one_node_nodes=probes_of_one_node.collect {|probe,description| description}.map {|e| e[:uid]}.flatten
puts "  #{probes_of_one_node.size} pdu measurements points (ports) only referenced by one node (to nodes #{compact_nodes(probes_of_one_node_nodes)})" if probes_of_one_node.size > 0

probes_of_multiple_nodes=pdu_nodes.select {|probe,description| description[:type]=="multiple"}
probes_of_multiple_nodes_nodes=probes_of_multiple_nodes.collect {|probe,description| description}.map {|e| e[:endpoints]}.flatten.map{|e| e[:uid]}
puts "  #{probes_of_multiple_nodes.size} pdu measurements points (ports) referenced by more than one node (to nodes #{compact_nodes(probes_of_multiple_nodes_nodes)})" if probes_of_multiple_nodes.size > 0

puts ""
printed_stuff=false

# check 'per_outlet' information
nodes_linked_to_pdus=[]
node_power_connectivity.each do |connectivity,nodes| 
  nodes.uniq!
  nodes_linked_to_pdus+=nodes.map{|n| n["uid"]}
  if nodes.size != 0
    puts "  #{nodes.size} nodes have a #{connectivity} power measurement according to pdu description from site/<site>/pdus for all their pdus as referenced by ['sensors']['power']['via']['pdu'] in the reference API (#{compact_nodes(nodes.map{|n| n["uid"]})})"
    printed_stuff=true
  end
end

# check ['via']['pdu'] and ['via']['api'] 
#    ['via']['pdu'] but no ['via']['api'] only acceptable if the pdu is not monitored (but why describe it then)
pdu_but_not_api=nodes_linked_to_pdus-nodes_with_metrics
if pdu_but_not_api.size > 0
  puts "  #{pdu_but_not_api.size} nodes have ['sensors']['power']['via']['pdu'] information, but no ['sensors']['power']['via']['api'] metric referenced in the API (#{compact_nodes(pdu_but_not_api)}): allowed" 
  printed_stuff=true
end

# check ['via']['pdu'] and ['via']['api'] 
#    ['via']['api'] but no ['via']['pdu'] not acceptable
api_but_not_pdu=nodes_with_metrics-nodes_linked_to_pdus
if api_but_not_pdu.size > 0
  puts "  #{api_but_not_pdu.size} nodes have power metrics referenced in the API but no pdu information (#{compact_nodes(api_but_not_pdu)}): should not happen" 
  printed_stuff=true
  api_but_not_pdu.each do |node|
    site_errors[nodes_site[node]] << "#{node} has a #{nodes_index[node]['sensors']['power']['via']['api']['metric']} metric described in the API, but no pdu information in ['sensors']['power']['via']['pdu'] to understand it" 
  end
end

puts "" if printed_stuff
printed_stuff=false

# Check all sites that have nodes advertising the "power" metric
# accessible via the api
# but no power metric reachable through metrology API
sites_with_power_in_reference_api.uniq!
reference_but_not_kwapi_sites=sites_with_power_in_reference_api-sites_with_power_in_metrology_api
if reference_but_not_kwapi_sites.size > 0
  puts "#{reference_but_not_kwapi_sites.size} sites have nodes advertising a \"power\" metric but none visible from the metrology API (kwapi not installed ?) (#{reference_but_not_kwapi_sites})"
  printed_stuff=true
end

# Check all sites that have kwapi installed, but no nodes
# advertising a "power" metric accessible via the api
kwapi_but_not_reference_sites=sites_with_power_in_metrology_api-sites_with_power_in_reference_api
if kwapi_but_not_reference_sites.size > 0
  puts "#{kwapi_but_not_reference_sites.size} sites are advertising a \"power\" metric, probably produced by kwapi, but have no nodes advertising it as a metric accessible through the API (#{kwapi_but_not_reference_sites})"
  printed_stuff=true
end

puts "" if printed_stuff
printed_stuff=false

puts "Information from the 'power' metric as related to nodes through pdu mapping in the reference API"
if api_metric_nodes.has_key?("power") 
  api_but_not_metrics=api_metric_nodes["power"]-power_nodes 
  if api_but_not_metrics.size > 0
    puts "  #{api_but_not_metrics.size} nodes advertised as having 'power' metric accessible through the API (see ['sensors']['power']['via']['api']), but not visible through the 'power' metric (#{compact_nodes(api_but_not_metrics)})"
    api_but_not_metrics.each do |node|
      site_errors[nodes_site[node]] << "#{node} advertised as having 'power' metric in ['sensors']['power']['via']['api'], but not visible through the 'power' metric (see metrics[:power]['available_on'])"
    end
  end
  
  metrics_but_not_api=power_nodes-api_metric_nodes["power"] 
  if metrics_but_not_api.size > 0
    puts "  #{metrics_but_not_api.size} nodes visible through the 'power' metric but not referencing access through the reference API in ['sensors']['power']['via']['api'] via 'power' (#{compact_nodes(metrics_but_not_api)})" 
    metrics_but_not_api.each do |node|
      site_errors[nodes_site[node]] << "#{node} visible through the 'power' metric but not referencing access through the reference API in ['sensors']['power']['via']['api'] via 'power'"
    end
  end
else
  puts "  no node with a metric named 'power'. kwapi probably not installed"
end

pdu_but_not_available_on=nodes_linked_to_pdus-power_nodes
if pdu_but_not_available_on.size > 0
  puts "  #{pdu_but_not_available_on.size} nodes have ['sensors']['power']['via']['pdu'] information, but are not linked to a probe referenced by metrics[:power]['available_on'] (#{compact_nodes(pdu_but_not_available_on)})" 
  pdu_but_not_available_on.each do |node|
    site_errors[nodes_site[node]] << "#{node} has ['sensors']['power']['via']['pdu'] information, but is not linked to a probe referenced by metrics[:power]['available_on']"
  end
end

puts "\n********* Error summary ******************************"

pp site_errors 
