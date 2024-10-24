#!/usr/bin/ruby
str = STDIN.tty? ? "Cannot read from STDIN" : $stdin.read
exit(1) unless str

require "json"

input = File.read("./res")
results = JSON.parse(input).to_json

STDOUT.write(results)

