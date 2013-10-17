#!/usr/bin/ruby
#
# Author: Jean-Francois Theroux <me@failshell.io>
#
# This script facilitate the reindexation of an
# Elastic Search index.

require 'rubygems'
require 'tire'

unless ARGV[0] and ARGV[1]
  puts 'USAGE: ./es-reindexer.rb source_index destination_index'
  exit 1
end

Tire.configure do
  url "http://lp-es-01:9200"
end

Tire.index(ARGV[0]).reindex(ARGV[1])
