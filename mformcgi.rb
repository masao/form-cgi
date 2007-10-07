#!/usr/bin/env ruby
# $Id$

require "erb"
require "yaml"
require "cgi"

class CGI
   def valid?( param )
      params[param] and params[param][0] and params[param][0].size > 0
   end
end

class Config
   def initialize( confio )
      @conf = YAML.load( confio )
   end
   def []( name )
      @conf[ name.to_s ]
   end
end

class FormComponent
   attr_reader :id
   def initialize( id, opt )
      @id = id
      @opt = {}
      opt.each do |k,v|
         @opt[ k ] = v
      end
   end
   def self.form2class( f )
      case f[ "type" ]
      when "text"
         FormText
      when "file"
         FormFile
      when "submit"
         FormSubmit
      else
         raise "Unknown form type: #{ f["type"].inspect }"
      end
   end
   def method_missing( name, *args )
      @opt[ name.to_s ]
      #else
      #      raise NameError, "undefined method: #{ name }"
      #   end
   end
   def escapeHTML( str )
      CGI.escapeHTML( str )
   end
end
class FormText < FormComponent
   def to_html
      size = if @opt["size"]
                %Q| size="#{ @opt["size"] }"|
             end
      %Q|<input type="text" name="#{ @id }" value=""#{ size }>|
   end
end
class FormFile < FormComponent
   def to_html
      %Q|<input type="file" name="#{ @id }" value=""></input>|
   end
end
class FormSubmit < FormComponent
   def to_html
      %Q|<input type="submit" name="#{ @id }" value=""></input>|
   end
end

class FormBuilder
   include Enumerable
   def initialize( form_conf )
      @forms = []
      form_conf.each_with_index do |f, idx|
         klass = FormComponent.form2class( f )
         @forms << klass.new( "form#{idx}", f )
      end
   end
   def each
      @forms.each do |e|
         yield e
      end
   end
end

class RequiredFormMissingError < Exception; end

class FormCGI
   def initialize
      @cgi = CGI.new
      @conf = Config.new( open("uploader.conf") )
      @forms =  FormBuilder.new( @conf["forms"] )
   end
   def execute
      rhtml = nil
      case action
      when "default"
         rhtml = "index.rhtml"
      when "save"
         begin
            save
            rhtml = "save.rhtml"
         rescue RequiredFormMissingError => e
            rhtml = "index.rhtml"
            #STDERR.puts e.message
            @error_message = e.message
         end
      else
         raise "unknown action: #{action.inspect}"
      end
      html = do_eval_rhtml( rhtml )
      puts @cgi.header( "text/html; charset=euc-jp" )
      puts html
   end

   def save
      now = Time.now.strftime("%Y%m%d%H%M%S")
      @saved_data = {}
      @forms.each do |form|
         str = @cgi.params[ form.id ][0]
         if str.nil? or str.size == 0 and form.require?
            raise RequiredFormMissingError, "missing form value: #{form.label}:#{str.inspect}"
         end
         #STDERR.puts form.class
         case form.class.to_s
         when "FormFile"
            original_filename = str.original_filename
            extname = File.extname( original_filename )
            content = str.read
            #STDERR.puts content.inspect
            #STDERR.puts form.filename.inspect
            filename = nil
            eval( 'filename = "' + form.filename + '"', binding )
            #STDERR.puts filename.inspect
            open( File.join( @conf[:data_dir], filename ), "w" ) do |io|
               io.print content
            end
            str = filename
         else
            str = str.read
            if str and not str.empty?
               str.gsub( /\t/, " " ).delete( "\0" )
            end
         end
         @saved_data[ form.id ] = str
      end
      #STDERR.puts @forms.inspect
      #STDERR.puts @forms.map{|e| @saved_data[e.id] or "" }.inspect
      open( File.join( @conf[:data_dir], "data.csv" ), "a" ) do |io|
         io.puts( ( [ now ] + @forms.map{|e| @saved_data[ e.id ] or "" } ).join("\t") )
      end
   end

   def action
      if @cgi.valid?("action")
         @cgi.params["action"][0].string
      else
         "default"
      end
   end

   include ERB::Util
   def do_eval_rhtml( rhtml )
      ERB::new( open( "html/" + rhtml ).read, nil, "<>" ).result( binding )
   end
end
