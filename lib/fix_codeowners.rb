#!/usr/bin/env ruby

require 'erb'

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

  eval(string_to_json(response.body).to_s)
end

def create_codeowners_file(team_members)
  @codeowners_string = team_members.map{|user| '@' + user.first}.join(' ')
  ERB.new(File.read('../util/codeowners_template.erb')).result(binding)
end

def commit_codeowners_file(base_url, token, repo_name, location, branch_name, string)
  full_url = base_url + "/repos/#{repo_name}/contents/#{location}CODEOWNERS"
  body_hash = {
    'branch' => branch_name,
    'message' => 'Fix codeowners',
    'content' => Base64.encode64(string)
  }
  response = execute_put(full_url, token, body_hash)

  if response.code != '201' || response.body == '[]'
    raise StandardError, "#{$x_mark} lob could not be created: #{response.body}".red
    exit
  end

  eval(string_to_json(response.body).to_s)
end

base_url, token, team_id, team_members = initialization

repo_name = ''
if ARGV[5].nil?
  input_file_name = 'analyze_codeowners_results.json'
  input_file = File.read(input_file_name)
  input_file_hash = JSON.parse(input_file)
else
  repo_name = ARGV[5]
end

branch_name = 'master'
puts
puts "#{$check_mark} Default branch name is #{branch_name}".yellow

change_branch = request_input("Press enter to continue or type something to change the branch name")
branch_name = change_branch unless change_branch.empty?

main_branch_sha = get_branch_sha(base_url, token, repo_name, branch_name)
puts
puts "#{$check_mark} Master branch found starting with commit \"#{main_branch_sha}\"".green

# branch_name = 'test2'
branch_name = ARGV[6]

new_branch = create_branch(base_url, token, repo_name, branch_name, main_branch_sha)
# new_branch = create_branch(base_url, token, repo_name, 'fix_codeowners', main_branch_sha)
# puts new_branch['ref']
# new_branch = 'refs/heads/test2'

puts
puts "#{$check_mark} New branch named \"#{branch_name}\" created".green

codeowners_location = '.github/'


commit_codeowners_file(base_url, token, repo_name, codeowners_location, branch_name, create_codeowners_file(team_members))

puts
puts "#{$check_mark} CODEOWNERS file committed to \"#{branch_name}\" branch".green
