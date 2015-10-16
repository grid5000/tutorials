#!/usr/bin/env ruby

# (c) 2012-2015 Inria by David Margery (david.margery@inria.fr) in the context of the Grid'5000 project
# Licenced under the CeCILL B licence.

require 'net/http'
require 'net/https'
require 'openssl'
require 'uri'
require 'rubygems'
require 'json'
require 'pp'

# by default, net/https does not trust
# any certificate authority
store = OpenSSL::X509::Store.new
store.set_default_paths

# create the http object modeling the connexion
# to the API

https = Net::HTTP.new('api.grid5000.fr',443)
req = Net::HTTP::Get.new('/stable')
https.use_ssl = true
https.verify_mode = OpenSSL::SSL::VERIFY_NONE

# WARNING: For an usage outside of grid5000 add a basic auth:
#req.basic_auth("user", "pass")

def fetch_url(https,req)
  res = https.request(req)
  case res
  when Net::HTTPSuccess
    answer=JSON.parse(res.body)
    return answer
  else
    puts "HTTP Error #{res.code} calling #{https}"
    res.error!
  end
end

def get_link(root, name)
  root["links"].collect { |item| item["href"] if item["rel"] == name }.compact.first
end

root=fetch_url(https,req)
puts root

sites_url=get_link(root,"sites")
req = Net::HTTP::Get.new(sites_url)
# WARNING: For an usage outside of grid5000 add a basic auth:
#req.basic_auth("user", "pass")

all_sites=fetch_url(https,req)

all_sites["items"].each do |site|
  puts site["name"]
end

