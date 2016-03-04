require 'sinatra/base'
require 'json'
require 'securerandom'

module ChatDemo
  class App < Sinatra::Base
    get "/" do
      erb :"index.html"
    end

    get "/assets/js/application.js" do
      content_type :js
      @scheme = ENV['RACK_ENV'] == "production" ? "wss://" : "ws://"
      erb :"application.js"
    end

    get "/register" do
      erb :"register.html"
    end

    post "/register" do
      uri = URI.parse(ENV["REDISCLOUD_URL"])
      @redis ||= Redis.new(host: uri.host, port: uri.port, password: uri.password)
      puts "#{params}"

      if params['incoming-url'].nil? || params['outgoing-token'].nil? || params['support-name'].nil? || params['welcome-message'].nil?
        { :error => "Keys missing"}.to_json
      else
        configuration_message = "This group will now receive messages from users using Flockster."
	`curl -X POST -d '{"text":"#{configuration_message}"}' -H "Content-Type:application/json;charset=UTF-8" https://api.flock.co/hooks/sendMessage/df4df2e4-c2fe-4f70-86fe-7bfdd09c7b15`
        outgoing_token = params['outgoing-token']
	current_uuid = @redis.get(outgoing_token)
	if current_uuid.nil?
          uuid = SecureRandom.uuid
	  hash = Hash.new
	  hash['incoming-url'] = params['incoming-url']
	  hash['outgoing-token'] = params['outgoing-token']
	  hash['support-name'] = params['support-name']
	  hash['welcome-message'] = params['welcome-message']
          @redis.set(uuid, hash)
	  @redis.set(outgoing_token, uuid)
          { :uuid => uuid }.to_json
	else
          { :uuid => current_uuid}.to_json
	end
      end
    end

    post "/support" do
      uri = URI.parse(ENV["REDISCLOUD_URL"])
      @redis ||= Redis.new(host: uri.host, port: uri.port, password: uri.password)
      puts "#{params}"
      data = JSON.parse(request.body.read.to_s)
      values = data['text'].split(':')
      user = values[0]
      text = values[1]
      unless text.nil?
        hash = Hash.new
        hash['handle'] = "Support"
        hash['text'] = text
	hash['user'] = user
        @redis.publish("chat-demo", hash.to_json)
      else
	if user == "This group will now receive messages from users using Flockster."
          puts "Received configuration message back"
	  outgoing_token = params['token']
	  uuid = @redis.get(outgoing_token)
	  hash_string = @redis.get(uuid)
	  puts "hash is #{hash_string}"
	  hash = JSON.parse hash_string.gsub('=>', ':')
	  hash['guid'] = data['from'].split('/')[0]
          @redis.set(uuid, hash)
	end
      end
    end
  end
end
