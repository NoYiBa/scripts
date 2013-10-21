#!/opt/sensu/embedded/bin/ruby

require 'rest_client'
require 'json'

url = 'http://user:pass@host:55672/api/queues/%2Fsensu'
r = RestClient.get url
JSON.parse(r).each do |e|
  if e['messages'] > 100
    puts "#{e['name']} => #{e['messages']}"
    `curl -L -H "content-type:application/json" -XDELETE http://user:pass@host:55672/api/queues/%2Fsensu/#{e['name']}`
  end
end
