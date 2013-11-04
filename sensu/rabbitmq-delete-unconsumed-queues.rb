#!/opt/sensu/embedded/bin/ruby

require 'rest_client'
require 'json'

url = 'http://user:secret@server:55672/api/queues/%2Fsensu'
r = RestClient.get url
JSON.parse(r).each do |e|
  if e['messages'] > 100
    puts "#{e['name']} => #{e['messages']}"
    `curl -L -u user:secret -H "content-type:application/json" -XDELETE http://user:secret@server:55672/api/queues/%2Fsensu/#{e['name']}`
  end
end
