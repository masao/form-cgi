#!/usr/bin/env ruby
# $Id$

require "mformcgi.rb"

begin
   cgi = CGI.new
   klass = nil
   if cgi.valid?( "action" )
      case cgi.value( "action" )
      when "default"
         klass = FormCGI
      when "save"
         klass = FormCGISave
      else
         raise "unknown action: #{ cgi.params["action"][0].inspect }"
      end
   else
      klass = FormCGI
   end
   formapp = klass.new( cgi )
   print cgi.header( "text/html; charset=euc-jp" )
   puts formapp.to_html
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
