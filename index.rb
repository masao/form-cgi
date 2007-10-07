#!/usr/bin/env ruby
# $Id$

require "mformcgi.rb"

begin
   formapp = FormCGI.new
   formapp.execute
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
