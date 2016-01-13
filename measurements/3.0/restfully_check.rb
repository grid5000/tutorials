# (c) 2016 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

nb_sites=root.sites.count 
if nb_sites > 0
  puts "Successfully connected to the API and found #{nb_sites} sites on Grid'5000"
else
  puts "Found no sites. Something is wrong"
end
