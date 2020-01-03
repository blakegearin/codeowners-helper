#!/usr/bin/env ruby

require_relative '../util/initialization.rb'
require_relative '../util/rest.rb'
require_relative '../util/styling.rb'

def get_branch_sha(base_url, token, repo_name, branch_name)
  full_url = base_url + "/repos/#{repo_name}/git/refs/heads/#{branch_name}"

  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x_mark} Repo not found: #{response.body}".red
    exit
  end

  array_response = eval(string_to_json(response.body).to_s)

  array_response['object']['sha']
end

def create_branch(base_url, token, repo_name, branch_name, sha)
  full_url = base_url + "/repos/#{repo_name}/git/refs"

  body_hash = {
    'ref' => "refs/heads/#{branch_name}",
    'sha' => sha.to_s
  }

  response = execute_post(full_url, token, body_hash)
  if response.code == '422'
    raise StandardError, "#{$x_mark} A branch with the name \"#{branch_name}\" already exists for the \"#{repo_name}\" repo: #{response.body}".red
    exit
  elsif response.code != '201' || response.body == '[]'
    raise StandardError, "#{$x_mark} Branch could not be created: #{response.body}".red
    exit
  end

  array_response = eval(string_to_json(response.body).to_s)

  array_response['ref']
end

base_url, token, team_id, team_members = initialization

if ARGV[5].nil?
  input_file_name = 'analyze_codeowners_results.json'
  input_file = File.read(input_file_name)
  input_file_hash = JSON.parse(input_file)
else
  repo_name = ARGV[5]
  master_branch_sha = get_branch_sha(base_url, token, repo_name, 'master')
  puts master_branch_sha

  new_branch_ref = create_branch(base_url, token, repo_name, ARGV[6], master_branch_sha)
  puts new_branch_ref
end
