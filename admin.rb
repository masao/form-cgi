#!/usr/bin/env ruby
# $Id$

require_relative "mformcgi.rb"

begin
   cgi = CGI.new
   formapp = FormCGIAdmin.new( cgi )

   case cgi.value('format')
   when "txt", "csv"
     print cgi.header( "text/plain; charset=utf-8" )
     puts formapp.to_csv
   else
     print cgi.header( "text/html; charset=utf-8" )
     puts formapp.to_html
   end
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
