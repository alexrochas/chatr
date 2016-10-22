#!/usr/bin/ruby

require 'vrlib'

#make program output in real time so errors visible in VR.

#everything in these directories will be included
project_path = File.expand_path(File.dirname(__FILE__))
lib_path = project_path + '/bin/**/*.rb'
require_all Dir.glob(lib_path)

MyClass.new.show_glade
