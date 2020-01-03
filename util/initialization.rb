#!/usr/bin/env ruby

require 'json'

require_relative '../util/rest.rb'
require_relative '../util/styling.rb'

def validate_hostname(hostname, prompt)
  base_url = ''
  loop do
    base_url = "https://#{hostname}/api/v3"
    response = execute_get(base_url)
    break unless response.nil?

    puts
    puts "#{$x_mark} The hostname \"#{hostname}\" was not found".red
    hostname = request_input(prompt)
  end

  puts
  puts  "#{$check_mark} Hostname has been found".green

  base_url
end

def initialize_base_url(command_line_argument, prompt)
  hostname = (command_line_argument.nil?) ?  request_input(prompt) : command_line_argument

  validate_hostname(hostname, prompt)
end

def validate_token_key(base_url, token_key, prompt)
  token = ''
  full_url = base_url + '/user'

  loop do
    token = "token #{token_key}"
    response = execute_get(full_url, token)

    break if response.code == '200'

    puts
    puts "#{$x_mark} The token key \"#{token_key}\" is not valid".red
    token_key = request_input(prompt)
  end

  puts
  puts  "#{$check_mark} Token has been validated".green

  token
end

def initialize_token(base_url, command_line_argument, prompt)
  token_key = (command_line_argument.nil?) ?  request_input(prompt) : command_line_argument

  validate_token_key(base_url, token_key, prompt)
end

def validate_organization(base_url, token, organization_name, prompt)
  organization_response = ''
  loop do
    full_url = base_url + "/orgs/#{organization_name}"
    organization_response = execute_get(full_url, token)

    break if organization_response.code == '200'

    puts
    puts "#{$x_mark} The organization \"#{organization_name}\" was not found".red
    organization_name = request_input(prompt)
  end

  puts
  puts  "#{$check_mark} Organization has been found".green

  organization_response.body
end

def initialize_organization(base_url, token, command_line_argument, prompt)
  organization = (command_line_argument.nil?) ?  request_input(prompt) : command_line_argument

  organization_response_body = validate_organization(base_url, token, organization, prompt)

  eval(string_to_json(organization_response_body).to_s)
end

def validate_team(base_url, token, organization_name, team, prompt)
  team_response = ''
  loop do
    full_url = base_url + "/orgs/#{organization_name}/teams/#{team}"
    team_response = execute_get(full_url, token)

    break if team_response.code == '200'

    puts
    puts "#{$x_mark} The team \"#{team}\" was not found in the \"#{organization_name}\" organization.".red
    team = request_input(prompt)
  end

  puts
  puts "#{$check_mark} Team has been found".green

  team_response.body
end

def initialize_team(base_url, token, organization_name, command_line_argument, prompt)
  team = (command_line_argument.nil?) ?  request_input(prompt) : command_line_argument

  team_response_body = validate_team(base_url, token, organization_name, team, prompt)

  eval(string_to_json(team_response_body).to_s)
end

def get_team(base_url, token, organization, team_name)
  full_url = base_url + "/orgs/#{organization}/teams/#{team_name}"
  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x_mark} Team not found: #{response.body}".red
    exit
  end

  eval(string_to_json(response.body).to_s)
end

def get_name(base_url, token, username)
  full_url = base_url + "/users/#{username}"

  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x_mark} User with username #{username} not found: #{response.body}".red
    exit
  end

  array_response = eval(string_to_json(response.body).to_s)
  array_response['name']
end

def get_team_members(base_url, token, team_id)
  full_url = base_url + "/teams/#{team_id}/members"

  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x_mark} No team members not found: #{response.body}".red
    exit
  end

  array_response = eval(string_to_json(response.body).to_s)

  team_members = []

  array_response.each do |team_member|
    username = team_member['login']
    name = get_name(base_url, token, username)
    team_member_array = [username.downcase, name]
    team_members.push(team_member_array)
  end

  team_members.sort
end

def print_team_member(team_member)
  "Username: #{team_member[0]}  |  Name: #{team_member[1]}"
end

def print_team_members(team_members_array)
  for i in 0..team_members_array.length-1 do
    extra_spaces = calculate_extra_spaces(i+1, team_members_array)
    puts "  #{i+1}.#{extra_spaces} #{print_team_member(team_members_array[i])}"
  end
end

def remove_items_prompt(array, name_of_items, print_all_function, print_one_function = nil)
  puts
  puts "Would you like to remove a #{name_of_items}? y/n or enter to skip"

  loop do
    print "Input: ".blue
    remove_items = STDIN.gets.chomp
    break if ['n', 'no', ''].include?(remove_items.downcase)

    if ['y', 'yes'].include?(remove_items.downcase)
      loop do
        puts
        puts "Enter the number of #{name_of_items} you would you like to remove or enter multiple separated by commas."
        print "Input: ".blue
        to_remove_string = STDIN.gets.chomp

        removed = remove_from_array(to_remove_string, array, name_of_items, print_one_function)

        break if removed
      end

      puts
      puts "#{array.length} #{name_of_items}#{array.length == 1 ? '' : 's'} remaining".green
      print_all_function.call(array)
      break if array.length == 0
    else
      puts
      puts "#{$x_mark} Invalid input; enter yes, y, no, n, or enter".red
    end
    puts
    puts "Would you like to remove some more #{name_of_items}s? y/n"
  end

  array
end

def initialization
  base_url = initialize_base_url(ARGV[0],
      'Please enter your GitHub Enterprise hostname. It follows this pattern: "github.[foobar].com"')
  token = initialize_token(base_url, ARGV[1], 'Please enter your token key. Do not including the word token.')

  organization = initialize_organization(base_url, token, ARGV[2], 'Please enter your organization name.')
  organization_name = organization['name']
  puts "  - Name: #{organization_name}"
  puts "  - Id: #{organization['id']}"

  team = initialize_team(base_url, token, organization_name, ARGV[3], 'Please enter your team name.')
  team_id = team['id']
  puts "  - Name: #{team['name']}"
  puts "  - Id: #{team_id}"

  # Find team members
  team_members = get_team_members(base_url, token, team_id)

  puts
  puts "#{$check_mark} #{team_members.length} team members found".green
  print_team_members(team_members)

  case ARGV[4]
  when nil
  remove_items_prompt(team_members, 'team member', method(:print_team_members), method(:print_team_member))
  when '0'
  puts
  puts "#{$check_mark} Skipping removal of team members".yellow
  else
  remove_from_array(ARGV[4], team_members, 'team member', method(:print_team_member))
  end

  [
    base_url,
    token,
    team_id,
    team_members
  ]
end
