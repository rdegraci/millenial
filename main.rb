# Millenial

require 'rocketman'
require 'redis'
require 'rocketman/relay/redis' 
require 'sinatra'
require 'workers'
require 'date'
require 'json'

@@group = Workers::TaskGroup.new

class Consumer
  extend Rocketman::Consumer
  include Rocketman::Producer

  on_event :create_task do |payload|
  	source = payload[:payload]['source']

  	group = Workers::TaskGroup.new
		group.add(:max_tries => 10) do
  		g_terminate = false
  		b = binding
  	  l = eval("lambda { #{source} }", b)
  		while !g_terminate
  			l.call()	# g_terminate flag is available within the lambda
  		end
		end
  	Thread.new { group.run }
  end

  on_event :stdout do |payload|
  	pp payload
  	channel = payload[:payload]['channel']
  	emit(channel.to_sym, payload: payload) if channel && payload
  end

  on_event :write do |payload|
  	key = payload[:payload]['key']
  	@@redis.set key, payload.to_json
  end

  on_event :read do |payload|
  	key = payload[:payload]['key']
  	channel = payload[:payload]['channel']
  	json = @@redis.get(key)
  	emit(channel.to_sym, payload: json) if channel && json
  end

end

# NOTE: You should always pass in a new, dedicated connection to Redis to 
# the Redis relay. This is because redis.psubscribe will hog the whole 
# Redis connection (not just Ruby process), so Relay expects a dedicated 
# connection for itself.
@@redis = Redis.new(host: "localhost")

Rocketman::Relay::Redis.new.start(@redis)

Rocketman.configure do |config|
  config.worker_count = 10 # defaults to 5
  config.latency      = 1  # defaults to 3, unit is :seconds
  config.storage      = Redis.new # defaults to `nil`
  config.debug        = true # defaults to `false`
end

include Rocketman::Producer

# params should be
# {
# 	"source" : "sourcecode"
# }
# sourcecode is evaluated and executed in an infinte loop
# to end the loop, if desires, set g_terminate to true within
# the source code
post '/create_task' do
  emit :create_task, payload: params
end

# params should be something like
# GET /read?key=keyvalue&channel=channelvalue
# keyvalue is used to read from Redis, the resulting dictionary is published
# to the channelvalue.
get '/read' do
  emit :read, payload: params
end

# params should be
# {
# 	"key" : "keyvalue",
# 	"key1" : "data1"
#   "key2" : "data2"  
# 	... // etc
# }
# The whole dictionary is stored in Redis using the keyvalue as the key
post '/write' do
  emit :write, payload: params
end

# params could be
# {
#   "channel" : "channelvalue"  to send the results
# 	"key1" : "data1"
#   "key2" : "data2"
#   ... // etc
# }
# The whole params dictionary is pretty printed to the console
# the results are published to channel
post '/stdout' do
	emit :write, payload: params
end
