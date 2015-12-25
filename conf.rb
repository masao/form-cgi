#!/usr/bin/env ruby
# $Id$

require_relative "mformcgi.rb"

begin
   cgi = CGI.new
   if cgi.valid?( "action" )
      case cgi.value( "action" )
      when "default"
         klass = FormCGIConf
      when "save"
         klass = FormCGIConfSave
      when "form"
         klass = FormCGIConfForm
      when "form_new"
         klass = FormCGIConfFormNew
      when "user"
         klass = FormCGIConfUser
      when "user_new"
         klass = FormCGIConfUserNew
      else
         raise "unknown action: #{ cgi.params["action"][0].inspect }"
      end
   else # fallback to the default.
      klass = FormCGIConf
   end

   formapp = klass.new( cgi )

   print cgi.header( "text/html; charset=utf-8" )
   puts formapp.to_html
rescue
   print "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
