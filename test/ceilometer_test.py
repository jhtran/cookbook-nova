#!/usr/bin/python

import httplib
import json
import pprint

# spin up an openstack vm and provide the name for that vm, wait 5 minutes for
# polling to gather initial data.
vm_name = 'test1'
# provide a basic ceilometer vm metric to poll such as 'cpu'
meter_name = 'cpu'

keystone_url = "localhost:5000"
ceilometer_url = 'localhost:8777'

# Use keystone auth to get your standard OS access token
osuser = "ceilometer"
ospassword = "none"
ostenantname = "service"

params = '{"auth":{"passwordCredentials":{"username": "' + osuser + '", "password":"' + ospassword + '"}, "tenantName":"' + ostenantname + '"}}'
headers = {"Content-Type": "application/json"}

conn = httplib.HTTPConnection(keystone_url)
conn.request("POST", "/v2.0/tokens", params, headers)

response = conn.getresponse()
data = response.read()
dd = json.loads(data)

conn.close()

apitoken = dd['access']['token']['id']


# Find the resource_id that ceilometer assigned the vm
conn = httplib.HTTPConnection(ceilometer_url)
headers['X-Auth-Token'] =  apitoken
conn.request("GET", "/v1/resources", '', headers)
response = conn.getresponse()
data = response.read()
conn.close()
j = json.loads(data)

resource_id = None
for x in j['resources']:
  try:
    if x['metadata']['display_name'] == vm_name:
      resource_id = x['resource_id']
  except:
     continue

if not resource_id:
  raise Exception("VM %s not found!")

# Query based on resource_id for cpu meters
meter_url_path = "/v1/resources/%s/meters/%s" % (resource_id, meter_name)
conn.request("GET", meter_url_path, '', headers)
response = conn.getresponse()
data = response.read()
conn.close()
j = json.loads(data)
meters = j['events']
first_meter = meters[0]
assert first_meter['counter_name'] == 'cpu'
assert first_meter['counter_volume'] > 0
assert len(meters) > 1
print "Test Successful!"
