require 'faye/websocket'
require 'thread'
require 'redis'
require 'json'
require 'erb'

module ChatDemo
  class ChatBackend
    KEEPALIVE_TIME = 15 # in seconds
    CHANNEL        = "chat-demo"

    def initialize(app)
      @app     = app
      @clients = []
      @hash = Hash.new

      uri = URI.parse(ENV["REDISCLOUD_URL"])
      @redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
      Thread.new do
        redis_sub = Redis.new(host: uri.host, port: uri.port, password: uri.password)
        redis_sub.subscribe(CHANNEL) do |on|
          on.message do |channel, msg|
	    puts "Need to send message"
            json = JSON.parse(msg)
	    user = json['user']
	    puts "Handle is #{user}"
	    ws = @hash[user]
	    puts "websocket: #{ws}"
	    ws.send(msg) unless ws.nil?
          end
        end
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
	puts "got websocket"
        ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })
        ws.on :open do |event|
          p [:open, ws.object_id]
          @clients << ws
        end

        ws.on :message do |event|
	  json = JSON.parse(event.data)
	  if json['text'].nil?
            puts "Got handle: #{json['handle']}"
	    @hash[json['handle']] = ws
	    ws.send({"support-name"=> "Flock Support", "welcome-message"=> "Hey. How can I help you?"}.to_json)
	  else
	    message = "#{json['handle']}: #{json['text']}"
	    `curl -X POST -d '{"text":"#{message}"}' -H "Content-Type:application/json;charset=UTF-8" https://api.flock.co/hooks/sendMessage/df4df2e4-c2fe-4f70-86fe-7bfdd09c7b15`
            p [:message, event.data]
	  end
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @clients.delete(ws)
	  #key = @hash.key(ws)
          #@hash.delete(key) unless key.nil?
          ws = nil
        end

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
    end

    private
    def sanitize(message)
      json = JSON.parse(message)
      json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end
  end
end
