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
        outgoing_token = params['outgoing-token']
	current_uuid = @redis.get(outgoing_token)
	if current_uuid.nil?
          uuid = SecureRandom.uuid
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
      end
    end
  end
end
