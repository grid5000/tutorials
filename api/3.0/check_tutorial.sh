#!/usr/bin/bash

# (c) 2012-2015 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

# To be run from the frontend, in the directory the script is in

curl -k https://api.grid5000.fr/stable
curl -k https://api.grid5000.fr/stable | json_pp
curl -k https://api.grid5000.fr/stable/?pretty=yes

restfully --uri https://api.grid5000.fr/stable restfully_count.rb
restfully --uri https://api.grid5000.fr/stable restfully_count_free.rb



