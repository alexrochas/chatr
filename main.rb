#!/usr/bin/ruby

require 'vrlib'

#make program output in real time so errors visible in VR.

#everything in these directories will be included
my_path = File.expand_path(File.dirname(__FILE__))
require_all Dir.glob(my_path + "/bin/**/*.rb")
begin
  MyClass.new.show
raise StandardError => e
  puts "Here"
  puts e
end

