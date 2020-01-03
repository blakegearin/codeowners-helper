#!/usr/bin/env ruby

require_relative '../util/initialization.rb'

def get_team_repos(base_url, token, team_id)
  array_response = []
  i = 1
  per_page = 100
  loop do
    full_url = base_url + "/teams/#{team_id}/repos?page=#{i}&per_page=#{per_page}"

    response = execute_get(full_url, token)
    if response.code != '200'
      raise StandardError, "#{$x_mark} No repos not found: #{response.body}".red
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

  extra_team_members
end

def print_repo_name_table(array)
  table = Terminal::Table.new :headings => ['Repo Name'],
      :rows => array.map { |item| [item] }
  puts table
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
      puts "#{$x_mark} #{to_remove_index} is not a valid number. Valid numbers are between 1 and #{array.length}".red
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
      remove_message = "#{$check_mark} Removing the #{name_of_items} at position #{index+1}: \"#{printed_item}\"".green
      puts
      puts remove_message
    array.delete_at(index)
  end

  removed
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
  puts "#{$check_mark} #{singular_or_plural(array.length)} no missing or extra team members".green
  return if array.length == 0

  table = Terminal::Table.new :headings => ['Repo Name'],
      :rows => array.map { |item| [item] }
  puts table
end

def print_extra_and_missing_team_members_repo(array)
  puts "#{$x_mark} #{singular_or_plural(array.length)} extra team members".yellow
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
  puts "#{$x_mark} #{singular_or_plural(array.length)} missing team members".yellow
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
  puts "#{$x_mark} #{singular_or_plural(array.length)} extra team members".yellow
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

  puts "#{$check_mark} #{repos_analyzed} repos analyzed".green
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

base_url, token, team_id, team_members = initialization

puts
puts "#{$check_mark} Will be analyzing repos with #{team_members.length} team members".green

# Find team repos
repo_names = get_team_repos(base_url, token, team_id)
puts
puts "#{$check_mark} #{repo_names.length} repos found".green
print_list(repo_names)

case ARGV[5]
when nil
  remove_items_prompt(repo_names, 'repo', method(:print_list))
when '0'
  puts
  puts "#{$check_mark} Skipping removal of repos".yellow
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
puts "#{$check_mark} Results saved to #{file_name}".green

print_results(status_arrays)
