#!/usr/bin/env ruby

require 'net/http'
require 'pry'
require 'uri'

def string_to_json(file)
  JSON.parse file.gsub('=>', ':')
end

def execute_get(url, token = nil)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri)
  request["Authorization"] = token unless token.nil?
  req_options = {
    use_ssl: uri.scheme == 'https'
  }
  Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
rescue SocketError => e
  nil
end

def execute_post(url, token, body_hash)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = body_hash.to_json
  request["Authorization"] = token
  req_options = {
    use_ssl: uri.scheme == 'https'
  }
  Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
rescue SocketError => e
  nil
end

def execute_put(url, token, body_hash)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Put.new(uri.request_uri)
  request.body = body_hash.to_json
  request["Authorization"] = token
  req_options = {
    use_ssl: uri.scheme == 'https'
  }
  Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
rescue SocketError => e
  nil
end
