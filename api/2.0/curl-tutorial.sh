#!/usr/bin/env bash

# This tutorial will show you how to use the [cURL](http://man.cx/curl) 
# command-line tool to issue one-shot requests against the Grid'5000 API.

# Prerequisites
# ---------------------------
# You'll need the cURL command-line tool. If it's not already installed, 
# use your package manager to fetch it. E.g.:
# 
#     sudo apt-get install curl
#

# Test that you can access the Grid'5000 API. Replace `login` and `password`
# with their respective value (your Grid'5000 credentials).
# The output of the command should be:
#
#     HTTP/1.1 200 OK
#     Date: Mon, 04 Apr 2011 09:22:37 GMT
#     Vary: Accept,Accept-Encoding
#     ETag: "f1930ff4bc894f7fa076ce8f2e029e1c6a4adfe7"
#     Allow: GET
#     Cache-Control: public, must-revalidate, proxy-revalidate, max-age=60, s-maxage=60
#     Last-Modified: Fri, 01 Apr 2011 15:38:10 GMT
#     Content-Length: 2366
#     Status: 200
#     Content-Type: application/vnd.fr.grid5000.api.site+json;level=1
#   
#     {
#       "name": "Rennes",
#       "latitude": 48.1,
#       "location": "Rennes, France",
#       "security_contact": "rennes-staff@lists.grid5000.fr",
#       "uid": "rennes",
#       "type": "site",
#       "user_support_contact": "rennes-staff@lists.grid5000.fr",
#       "version": "a650e837fbc8a4fbcc403ad25aa82cceab7babe4",
#       "links": [
#         {
#           "href": "/2.0/grid5000/sites/rennes/versions/a650e837fbc8a4fbcc403ad25aa82cceab7babe4",
#           "title": "version",
#           "rel": "member",
#           "type": "application/vnd.fr.grid5000.api.Version+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/versions",
#           "title": "versions",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes",
#           "rel": "self",
#           "type": "application/vnd.fr.grid5000.api.Site+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/clusters",
#           "title": "clusters",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/environments",
#           "title": "environments",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000",
#           "rel": "parent",
#           "type": "application/vnd.fr.grid5000.api.Grid+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/status",
#           "title": "status",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/metrics",
#           "title": "metrics",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/jobs",
#           "title": "jobs",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes/deployments",
#           "title": "deployments",
#           "rel": "collection",
#           "type": "application/vnd.fr.grid5000.api.Collection+json;level=1"
#         }
#       ],
#       "description": "",
#       "longitude": -1.6667,
#       "compilation_server": false,
#       "email_contact": "rennes-staff@lists.grid5000.fr",
#       "web": "http://www.irisa.fr",
#       "sys_admin_contact": "rennes-staff@lists.grid5000.fr"
#     }
#
# What you just did was getting the description of the `rennes` site. 
# The response is [JSON](http://json.org/) formatted (JSON is a lightweight data 
# interchange format), and contains a list of `links` to related resources.
curl -ki -u login:password https://api.grid5000.fr/2.0/grid5000/sites/rennes

# As an example, you can fetch the list of scheduled jobs on the `rennes` site by issuing a request to the following URI.
# You can remove the `-i` flag if you do not want to display the HTTP headers from the response.
curl -ki -u login:password https://api.grid5000.fr/2.0/grid5000/sites/rennes/jobs

# If you want to avoid entering your credentials for every request, `cURL` can 
# use a configuration file (`~/.netrc`) to store them.
# Then, you just have to pass the `-n` flag to `cURL` so that it takes it into account.
cat <<EOF >> ~/.netrc
machine api.grid5000.fr
login your-grid5000-login
password your-grid5000-password
EOF
chmod 600 ~/.netrc

# Retry the previous request with the `-n` flag, and you should get the same result.
curl -kni https://api.grid5000.fr/2.0/grid5000/sites/rennes/jobs

# At this point, you may want to add your very own job to the previous list.
# Use the `POST` method to create a new job that just sleeps for 30 minutes.
# You should get back a response like the following:
#
#     HTTP/1.1 201 Created
#     Date: Mon, 04 Apr 2011 09:51:39 GMT
#     Location: /2.0/grid5000/sites/rennes/jobs/381093
#     Content-Type: application/json
#     Content-Length: 337
#     Vary: Accept-Encoding
#   
#     {
#       "uid": 381093,
#       "links": [
#         {
#           "href": "/2.0/grid5000/sites/rennes/jobs/381093",
#           "rel": "self",
#           "type": "application/vnd.fr.grid5000.api.Job+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes",
#           "rel": "parent",
#           "type": "application/vnd.fr.grid5000.api.Site+json;level=1"
#         }
#       ]
#     }
#
curl -kni -X POST https://api.grid5000.fr/2.0/grid5000/sites/rennes/jobs \
-d 'command=sleep 1800'

# Notice the `201 Created` status code and the `Location` HTTP header in the previous response. 
# The latter indicates where the full job description can be fetched. 
# So let's see what we get:
#
#     HTTP/1.1 200 OK
#     Date: Mon, 04 Apr 2011 09:55:00 GMT
#     Content-Type: application/json
#     Content-Length: 790
#     Expires: Mon, 04 Apr 2011 09:55:30 GMT
#     Allow: GET, DELETE
#     Vary: Accept-Encoding
#   
#     {
#       "assigned_nodes": [
#         "paramount-7.rennes.grid5000.fr"
#       ],
#       "directory": "/home/crohr",
#       "command": "sleep 1800",
#       "mode": "PASSIVE",
#       "walltime": 3600,
#       "submitted_at": 1301910701,
#       "project": "default",
#       "events": [
#   
#       ],
#       "uid": 381093,
#       "user_uid": "crohr",
#       "links": [
#         {
#           "href": "/2.0/grid5000/sites/rennes/jobs/381093",
#           "rel": "self",
#           "type": "application/vnd.fr.grid5000.api.Job+json;level=1"
#         },
#         {
#           "href": "/2.0/grid5000/sites/rennes",
#           "rel": "parent",
#           "type": "application/vnd.fr.grid5000.api.Site+json;level=1"
#         }
#       ],
#       "types": [
#   
#       ],
#       "queue": "default",
#       "started_at": 1301910702,
#       "message": "FIFO scheduling OK",
#       "scheduled_at": 1301910702,
#       "state": "running",
#       "properties": "maintenance = 'NO'"
#     }
#
curl -kni https://api.grid5000.fr/2.0/grid5000/sites/rennes/jobs/381093

# We can see that our job is `running` on the node `paramount-7.rennes.grid5000.fr`.
# Since it does not do anything useful, we can kill it by issuing a `DELETE` request on its URI.
# You should get back a `202 Accepted` response:
#
#     HTTP/1.1 202 Accepted
#     Date: Mon, 04 Apr 2011 09:57:11 GMT
#     Content-Type: application/json
#     Content-Length: 0
#     X-Oar-Info: Deleting the job = 381093 ...REGISTERED. The job(s) [ 381093 ] will be deleted in a near future.
#     Vary: Accept-Encoding
#
curl -kni -X DELETE https://api.grid5000.fr/2.0/grid5000/sites/rennes/jobs/381093

# This concludes our short tour of using the Grid'5000 API with cURL.
# You will find many more examples in the respective documentation of each API.
# See <https://api.grid5000.fr> for links to the documentation.
