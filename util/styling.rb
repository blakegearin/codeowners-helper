#!/usr/bin/env ruby

require 'colorize'
require 'ruby-progressbar'
require 'terminal-table'

$check_mark = "\u2713".encode('utf-8')
$x_mark = "\u2717".encode('utf-8')

def calculate_extra_spaces(current_digit, array)
  current_number_of_digits = current_digit.to_s.size
  highest_number_digits = array.length.to_s.size
  extra_spaces_count = highest_number_digits - current_number_of_digits

  " " * extra_spaces_count
end

def request_input(prompt)
  puts
  puts prompt
  print 'Input: '.blue
  STDIN.gets.chomp
end
