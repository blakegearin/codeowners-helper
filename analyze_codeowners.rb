#!/usr/bin/env ruby

require 'colorize'
require 'json'
require 'net/http'
require 'pry'
require 'ruby-progressbar'
require 'terminal-table'
require 'uri'

$checkmark = "\u2713".encode('utf-8')
$x = "\u2717".encode('utf-8')

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

def request_input(prompt)
  puts
  puts prompt
  print 'Input: '.blue
  STDIN.gets.chomp
end

def validate_hostname(hostname, prompt)
  base_url = ''
  loop do
    base_url = "https://#{hostname}/api/v3"
    response = execute_get(base_url)
    break unless response.nil?

    puts
    puts "#{$x} The hostname \"#{hostname}\" was not found".red
    hostname = request_input(prompt)
  end

  puts
  puts  "#{$checkmark} Hostname has been found".green

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
    puts "#{$x} The token key \"#{token_key}\" is not valid".red
    token_key = request_input(prompt)
  end

  puts
  puts  "#{$checkmark} Token has been validated".green

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
    puts "#{$x} The organization \"#{organization_name}\" was not found".red
    organization_name = request_input(prompt)
  end

  puts
  puts  "#{$checkmark} Organization has been found".green

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
    puts "#{$x} The team \"#{team}\" was not found in the \"#{organization_name}\" organization.".red
    team = request_input(prompt)
  end

  puts
  puts "#{$checkmark} Team has been found".green

  team_response.body
end

def initialize_team(base_url, token, organization_name, command_line_argument, prompt)
  team = (command_line_argument.nil?) ?  request_input(prompt) : command_line_argument

  team_response_body = validate_team(base_url, token, organization_name, team, prompt)

  eval(string_to_json(team_response_body).to_s)
end

def string_to_json(file)
  JSON.parse file.gsub('=>', ':')
end

def get_team(base_url, token, organization, team_name)
  full_url = base_url + "/orgs/#{organization}/teams/#{team_name}"
  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x} Team not found: #{response.body}".red
    exit
  end

  eval(string_to_json(response.body).to_s)
end

def get_name(base_url, token, username)
  full_url = base_url + "/users/#{username}"

  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x} User with username #{username} not found: #{response.body}".red
    exit
  end

  array_response = eval(string_to_json(response.body).to_s)
  array_response['name']
end

def get_team_members(base_url, token, team_id)
  full_url = base_url + "/teams/#{team_id}/members"

  response = execute_get(full_url, token)
  if response.code != '200' || response.body == '[]'
    raise StandardError, "#{$x} No team members not found: #{response.body}".red
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

def get_team_repos(base_url, token, team_id)
  array_response = []
  i = 1
  per_page = 100
  loop do
    full_url = base_url + "/teams/#{team_id}/repos?page=#{i}&per_page=#{per_page}"

    response = execute_get(full_url, token)
    if response.code != '200'
      raise StandardError, "#{$x} No repos not found: #{response.body}".red
      exit
    end

    break if response.body == '[]'

    page_response = eval(string_to_json(response.body).to_s)
    page_response.each do |repo|
      array_response.push(repo)
    end

    i += 1
  end

  repos = []
  exclude_list = ['svc-hi-mesos', 'svcSpinnaker', 'km047283']
  array_response.each do |repo|
    name = repo['full_name']
    repos.push(name) unless exclude_list.any? { |s| s.include?(name) }
  end

  repos.sort
end

def check_github_directory_path(base_url, token, repo_name)
  full_url = base_url + "/repos/#{repo_name}/contents/.github/CODEOWNERS"
  execute_get(full_url, token)
end

def check_root_directory_path(base_url, token, repo_name)
  full_url = base_url + "/repos/#{repo_name}/contents/CODEOWNERS"
  execute_get(full_url, token)
end

def get_codeowners(full_url, token)
  response = execute_get(full_url, token)

  # Replace unrecognized characters with spaces
  encoded_response_body = response.body.encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => ' ')

  # Narrow response to the line with users
  codeowners_line = encoded_response_body[/\n\*(\s|@|\w)*/]

   # Remove excess characters
  team_members_found_string = codeowners_line.gsub(/(\n|\*|\@)/,'')

  team_members_found_array = team_members_found_string.split(' ')
  team_members_found_array.map!(&:downcase)
end

def missing_team_members_test(team_members, users_in_codeowners_file)
  missing_team_members = []

  team_members.each do |team_member|
    username = team_member[0]
    missing_team_members.push(username) unless users_in_codeowners_file.include?(username)
  end

  missing_team_members
end

def extra_team_members_test(team_members, users_in_codeowners_file)
  extra_team_members = users_in_codeowners_file.dup

  team_members.each do |team_member|
    username = team_member[0]
    extra_team_members.delete(username) if users_in_codeowners_file.include?(username)
  end

  # binding.pry
  extra_team_members
end

def calculate_extra_spaces(current_digit, array)
  current_number_of_digits = current_digit.to_s.size
  highest_number_digits = array.length.to_s.size
  extra_spaces_count = highest_number_digits - current_number_of_digits

  " " * extra_spaces_count
end

def print_repo_name_table(array)
  table = Terminal::Table.new :headings => ['Repo Name'],
      :rows => array.map { |item| [item] }
  puts table
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

def print_list(array)
  for i in 0..array.length-1 do
    extra_spaces = calculate_extra_spaces(i+1, array)
    puts "  #{i+1}.#{extra_spaces} #{array[i]}"
  end
end

def remove_from_array(to_remove_string, array, name_of_items, print_one_function = nil)
  to_remove_array = to_remove_string.gsub(' ','').split(',').map(&:to_i)
  to_remove_array = to_remove_array.sort.reverse

  # Find which to delete
  removed = false
  to_delete = []
  to_remove_array.each do |to_remove_index|
    valid_input_test = to_remove_index >= 1 && to_remove_index <= array.length
    if valid_input_test
      to_delete.push(to_remove_index-1)
      removed = true
    else
      puts
      puts "#{$x} #{to_remove_index} is not a valid number. Valid numbers are between 1 and #{array.length}".red
    end
  end

  # Only consider unique input items
  to_delete = to_delete.uniq

  # Delete the items
  to_delete.each do |index|
    printed_item =
        if print_one_function.nil?
          array[index-1]
        else
          print_one_function.call(array[index])
        end
      remove_message = "#{$checkmark} Removing the #{name_of_items} at position #{index+1}: \"#{printed_item}\"".green
      puts
      puts remove_message
    array.delete_at(index)
  end

  removed
end

def remove_items_prompt(array, name_of_items, print_all_function, print_one_function = nil)
  puts
  puts "Would you like to remove a #{name_of_items}? y/n"

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
      puts "#{$x} Invalid input. Enter yes, y, no, or n.".red
    end
    puts
    puts "Would you like to remove some more #{name_of_items}s? y/n"
  end

  array
end

def initialize_status_arrays
  {
    'github_directory_path' => {
      'team_members_correct' => [],
      'team_members_extra_and_missing' => [],
      'team_members_missing' => [],
      'team_members_extra' => []
    },
    'root_directory_path' => {
      'team_members_correct' => [],
      'team_members_extra_and_missing' => [],
      'team_members_missing' => [],
      'team_members_extra' => []
    },
    'duplicate_codeowners' => [],
    'missing_codeowners' => []
  }
end

def singular_or_plural(number)
  if number == 1
    '1 repo has'
  else
    "#{number} repos have"
  end
end

# Sort repos into status arrays
def sort_repos(progress_bar, base_url, token, team_members, repo_names, status_arrays)
  github_directory_path_codeowners = status_arrays['github_directory_path']
  root_directory_path_codeowners = status_arrays['root_directory_path']
  duplicate_codeowners = status_arrays['duplicate_codeowners']
  missing_codeowners = status_arrays['missing_codeowners']

  repo_names.each do |repo_name|
    github_directory_path_response = ''
    root_directory_path_response = ''

    github_directory_path_response = check_github_directory_path(base_url, token, repo_name)
    github_directory_path = github_directory_path_response.code == '200'

    root_directory_path_response = check_root_directory_path(base_url, token, repo_name)
    root_directory_path = root_directory_path_response.code == '200'

    if github_directory_path && root_directory_path
      duplicate_codeowners.push(repo_name)
    elsif github_directory_path
      codeowners_download_url = eval(string_to_json(github_directory_path_response.body).to_s)['download_url']
      users_in_codeowners_file = get_codeowners(codeowners_download_url, token)

      missing_team_members = missing_team_members_test(team_members, users_in_codeowners_file)
      extra_team_members = extra_team_members_test(team_members, users_in_codeowners_file)

      if !missing_team_members.empty? && !extra_team_members.empty?
        github_directory_path_codeowners['team_members_extra_and_missing'].push(
          {
            'repo_name' => repo_name,
            'missing_team_members' => missing_team_members,
            'extra_team_members' => extra_team_members
          }
        )
      elsif !missing_team_members.empty?
        github_directory_path_codeowners['team_members_missing'].push(
          {
            'repo_name' => repo_name,
            'missing_team_members' => missing_team_members
          }
        )
      elsif !extra_team_members.empty?
        github_directory_path_codeowners['team_members_extra'].push(
          {
            'repo_name' => repo_name,
            'extra_team_members' => extra_team_members
          }
        )
      else
        github_directory_path_codeowners['team_members_correct'].push(repo_name)
      end
    elsif root_directory_path
      codeowners_download_url = eval(string_to_json(root_directory_path_response.body).to_s)['download_url']
      users_in_codeowners_file = get_codeowners(codeowners_download_url, token)

      missing_team_members = missing_team_members_test(team_members, users_in_codeowners_file)
      extra_team_members = extra_team_members_test(team_members, users_in_codeowners_file)

      if !missing_team_members.empty? && !extra_team_members.empty?
        root_directory_path_codeowners['team_members_extra_and_missing'].push(
          {
            'repo_name' => repo_name,
            'missing_team_members' => missing_team_members,
            'extra_team_members' => extra_team_members
          }
        )
      elsif !missing_team_members.empty?
        root_directory_path_codeowners['team_members_missing'].push(
          {
            'repo_name' => repo_name,
            'missing_team_members' => missing_team_members
          }
        )
      elsif !extra_team_members.empty?
        root_directory_path_codeowners['team_members_extra'].push(
          {
            'repo_name' => repo_name,
            'extra_team_members' => extra_team_members
          }
        )
      else
        root_directory_path_codeowners['team_members_correct'].push(repo_name)
      end
    else
      missing_codeowners.push(repo_name)
    end
    progress_bar.increment
  end
end

def print_correct_team_members_repo(array)
  puts "#{$checkmark} #{singular_or_plural(array.length)} no missing or extra team members".green
  return if array.length == 0

  table = Terminal::Table.new :headings => ['Repo Name'],
      :rows => array.map { |item| [item] }
  puts table
end

def print_extra_and_missing_team_members_repo(array)
  puts "#{$x} #{singular_or_plural(array.length)} extra team members".yellow
  return if array.length == 0

  table = Terminal::Table.new :headings => ['Repo Name', 'Missing Team Members', 'Extra Team Members']
  array.each do |item|
    table.add_row [
      item['repo_name'],
      item['missing_team_members'].join(', '),
      item['extra_team_members'].join(', ')
    ]
  end
  puts table
end

def print_missing_team_members_repo(array)
  puts "#{$x} #{singular_or_plural(array.length)} missing team members".yellow
  return if array.length == 0

  table = Terminal::Table.new :headings => ['Repo Name', 'Missing Team Members']
  array.each do |item|
    table.add_row [
      item['repo_name'],
      item['missing_team_members'].join(', ')
    ]
  end
  puts table
end

def print_extra_team_members_repo(array)
  puts "#{$x} #{singular_or_plural(array.length)} extra team members".yellow
  return if array.length == 0

  table = Terminal::Table.new :headings => ['Repo Name', 'Extra Team Members']
  array.each do |item|
    table.add_row [
      item['repo_name'],
      item['extra_team_members'].join(', ')
    ]
  end
  puts table
end

def print_initial_findings(status_arrays)
  github_directory_path_codeowners = status_arrays['github_directory_path']
  root_directory_path_codeowners = status_arrays['root_directory_path']
  duplicate_codeowners = status_arrays['duplicate_codeowners']
  missing_codeowners = status_arrays['missing_codeowners']

  github_directory_path_codeowners_size = github_directory_path_codeowners['team_members_correct'].length +
      github_directory_path_codeowners['team_members_extra_and_missing'].length +
      github_directory_path_codeowners['team_members_missing'].length +
      github_directory_path_codeowners['team_members_extra'].length

  root_directory_path_codeowners_size = root_directory_path_codeowners['team_members_correct'].length +
      root_directory_path_codeowners['team_members_extra_and_missing'].length +
      root_directory_path_codeowners['team_members_missing'].length +
      root_directory_path_codeowners['team_members_extra'].length

  repos_analyzed = github_directory_path_codeowners_size +
      root_directory_path_codeowners_size +
      duplicate_codeowners.length +
      missing_codeowners.length

  # binding.pry

  puts "#{$checkmark} #{repos_analyzed} repos analyzed".green
  puts "  1. #{singular_or_plural(github_directory_path_codeowners_size)} a codeowners file located in .github/"
  puts "  2. #{singular_or_plural(root_directory_path_codeowners_size)} a codeowners file located in the root directory"
  puts "  3. #{singular_or_plural(duplicate_codeowners.length)} duplicate codeowners files"
  puts "  4. #{singular_or_plural(missing_codeowners.length)} no codeowners file"
end

def print_results(status_arrays)
  github_directory_path_codeowners = status_arrays['github_directory_path']
  root_directory_path_codeowners = status_arrays['root_directory_path']
  duplicate_codeowners = status_arrays['duplicate_codeowners']
  missing_codeowners = status_arrays['missing_codeowners']

  loop do
    puts
    print_initial_findings(status_arrays)
    puts
    detailed_results_prompt = 'If you\'d like to view detailed results, enter the number(s) of those you\'d like to see. Otherwise, hit enter'
    response = request_input(detailed_results_prompt)
    break if response == ''

    response_array = response.gsub(' ','').split(',').map(&:to_i).uniq.sort

    response_array.each do |response_index|
      puts

      case response_index
      when 1
        github_directory_path_codeowners_size = github_directory_path_codeowners.flatten(1).count
        puts "1. #{singular_or_plural(github_directory_path_codeowners_size)} a codeowners file located in .github/"

        print_correct_team_members_repo(github_directory_path_codeowners['team_members_correct'])
        print_extra_and_missing_team_members_repo(github_directory_path_codeowners['team_members_extra_and_missing'])
        print_missing_team_members_repo(github_directory_path_codeowners['team_members_missing'])
        print_extra_team_members_repo(github_directory_path_codeowners['team_members_extra'])
      when 2
        root_directory_path_codeowners_size = root_directory_path_codeowners.flatten(1).count
        puts "2. #{singular_or_plural(root_directory_path_codeowners_size)} a codeowners file located in the root directory"

        print_correct_team_members_repo(root_directory_path_codeowners['team_members_correct'])
        print_extra_and_missing_team_members_repo(root_directory_path_codeowners['team_members_extra_and_missing'])
        print_missing_team_members_repo(root_directory_path_codeowners['team_members_missing'])
        print_extra_team_members_repo(root_directory_path_codeowners['team_members_extra'])
      when 3
        puts "3. #{singular_or_plural(duplicate_codeowners.length)} duplicate codeowners files"
        print_repo_name_table(duplicate_codeowners)
      when 4
        puts "4. #{singular_or_plural(missing_codeowners.length)} no codeowners file"
        print_repo_name_table(missing_codeowners)
      when nil
        break
      else
        puts "#{response_index} is not a valid number. Valid numbers are between 1 and 4".red
      end
    end
  end
end

# Initialize required values
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
puts "#{$checkmark} #{team_members.length} team members found".green
print_team_members(team_members)

case ARGV[4]
when nil
  remove_items_prompt(team_members, 'team member', method(:print_team_members), method(:print_team_member))
when '0'
  puts
  puts "#{$checkmark} Skipping removal of team members".yellow
else
  remove_from_array(ARGV[4], team_members, 'team member', method(:print_team_member))
end

puts
puts "#{$checkmark} Will be analyzing repos with #{team_members.length} team members".green

# Find team repos
repo_names = get_team_repos(base_url, token, team_id)
puts
puts "#{$checkmark} #{repo_names.length} repos found".green
print_list(repo_names)

case ARGV[5]
when nil
  remove_items_prompt(repo_names, 'repo', method(:print_list))
when '0'
  puts
  puts "#{$checkmark} Skipping removal of repos".yellow
else
  remove_from_array(ARGV[5], repo_names, 'repo')
end

puts
puts "Analyzing #{repo_names.length} repos..."
progress_bar = ProgressBar.create(:total => repo_names.length, :format => '|%B|')

status_arrays = initialize_status_arrays
sort_repos(progress_bar, base_url, token, team_members, repo_names, status_arrays)

file_name = 'analyze_codeowners_results.json'
file = File.new(file_name, 'w')
file.write(JSON.pretty_generate(status_arrays))
file.close

puts
puts "#{$checkmark} Results saved to #{file_name}".green

print_results(status_arrays)
