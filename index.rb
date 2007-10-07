#!/usr/bin/env ruby
# $Id$

require "uploader.rb"

begin
   uploader = FormCGI.new
   uploader.execute
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
