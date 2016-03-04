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

      data_str = request.body.read.to_s
      if data_str.length > 0
        data = JSON.parse(data_str)
        hash = Hash.new
        hash[:incoming_url] = "incoming"
        hash[:outgoing_token] = "outgoing"
        hash[:support_name] = "support"
        hash[:welcome_message] = "Welcome Sir"

        uuid = SecureRandom.uuid
        @redis.set(uuid, hash)
        { :uuid => uuid }.to_json
      else
        { :error => "Data missing"}.to_json
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
