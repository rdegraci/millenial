# Millenial

require 'rocketman'
require 'redis'
require 'rocketman/relay/redis' 
require 'sinatra'
require 'workers'
require 'date'
require 'json'

# Storage connection
REDIS = Redis.new(host: "localhost")

GROUP = Workers::TaskGroup.new

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
  	REDIS.set key, payload.to_json
  end

  on_event :read do |payload|
  	key = payload[:payload]['key']
  	channel = payload[:payload]['channel']
  	json = REDIS.get(key)
  	emit(channel.to_sym, payload: json) if channel && json
  end

end

# NOTE: You should always pass in a new, dedicated connection to Redis to 
# the Redis relay. This is because redis.psubscribe will hog the whole 
# Redis connection (not just Ruby process), so Relay expects a dedicated 
# connection for itself.
Rocketman::Relay::Redis.new.start(Redis.new)

Rocketman.configure do |config|
  config.worker_count = 10 # defaults to 5
  config.latency      = 1  # defaults to 3, unit is :seconds
  config.storage      = Redis.new # defaults to `nil`
  config.debug        = true # defaults to `false`
end

include Rocketman::Producer

#########################
# Pub/Sub via tags      #
#########################

# Create a publisher (a topic/channel that is associated with tags)
# 
# params:
# {
#   'publisher' => {
#     'identifier' => 'guid'
#     'name' => 'name',
#     'topic' => 'topic',
#     'tags' =>  ['tag1', 'tag2']
#   }
# }
post '/publishers' do
  publisher = params[:publisher]

  REDIS.lpush("/publishers", publisher.to_json)
  REDIS.write("/publishers/#{publisher['identifier']}", publisher.to_json)

  REDIS.lpush("/topics/#{publisher['topic']}", publisher.to_json)

  tags = publisher['tags']
  tags.each do |tag|
    REDIS.lpush("/tags/#{tag}", publisher.to_json)
  end
  publisher.to_json
end


# Publish a payload to any topic/channel that matches these tags
# 
# params:
# {
#   'payload' => {
#     'tags' => ['tag1', 'tag2'],
#     'key1' => 'value1'
#     ...
#   }
# }
post '/payloads' do
  payload = params[:payload]
  tags = payload['tags']
  tags.each do |tag|
    publishers = REDIS.lrange("/tags/#{tag}", 0, -1)
    publishers.each do |publisher|
      channel = publisher['topic']
      emit(channel.to_sym, payload: payload) if channel && payload
    end
  end
  payload.to_json
end

# Get topics/channels that match these tags
# 
# params:
# {
#   'tags' => ['tag1', 'tag2']
# }
get '/topics' do
  tags = params[:tags]
  topics = []
  tags.each do |tag|
    publishers = REDIS.lrange("/tags/#{tag}", 0, -1)
    publishers.each do |publisher|
      topics << publisher['topic']     
    end
  end
  topics.to_json
end


get '/publishers' do
  REDIS.lrange("/publishers", 0, -1).to_json
end

#########################
# Programming Interface #
#########################

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
