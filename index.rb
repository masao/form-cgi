#!/usr/bin/env ruby
# $Id$

require "uploader.rb"

begin
   uploader = Uploader.new
   uploader.execute
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
