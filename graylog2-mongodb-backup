#!/usr/bin/env ruby
#
# This script backs up the MongoDB database for Graylog2.
# It doesn't copy the messages though, as it could take a lot
# storage.
#
# License: GPLv2

require 'mongo'
require 'trollop'

opts = Trollop::options do
    opt :server, 'MongoDB server', :type => String, :default => 'localhost'
    opt :username, 'User (default: none)', :type => String
    opt :password, 'Password (default: none)', :type => String
    opt :database, 'Database', :type => String, :default => 'graylog2'
    opt :port, 'Port', :type => String, :default => '27017', :short => 'P'
    opt :destdir, 'Destination directory', :type => String, :default => '/tmp', :short => 'D'
end

puts 'WARNING: Messages will NOT be on the backup.'
begin
    db = Mongo::Connection.new("#{opts[:server]}", "#{opts[:port]}").db("#{opts[:database]}")
    if opts[:username]
        db.authenticate("#{opts[:username]}", "#{opts[:password]}")
    end
rescue Mongo::AuthenticationError=>e
    puts "ERROR: #{e}"
    if not opts[:password]
        puts 'HINT: You need to use --password'
    end
    exit 1
rescue=>e
    puts "ERROR: #{e}"
    exit 1
end
db.collection_names.each do |c|
    if not c =~ /^messages$/
        cmd = "mongoexport -h #{opts[:server]} -d #{opts[:database]} -c #{c} -o #{opts[:destdir]}/#{opts[:database]}.#{c}.bson"
        if opts[:username]
            cmd = cmd + " -u #{opts[:username]} -p #{opts[:password]}"
        end
        begin
            `#{cmd} > /dev/null 2>&1`
            puts "Collection exported: #{c}"
        rescue Errno::ENOENT=>e
            puts "ERROR: Missing the mongo client?"
            exit 1
        end
    end
end
