#!/usr/bin/env ruby
# $Id$

require "erb"
require "yaml"
require "cgi"

class CGI
   def valid?( param )
      params[param] and params[param][0] and params[param][0].size > 0
   end
   def value( opt )
      @data ||= {}
      if @data[opt]
         @data[opt]
      else
         data = params[opt][0]
         #STDERR.puts data.inspect
         if multipart? and data.respond_to?( :read )
            @data[opt] = data.read
         else
            @data[opt] = data
         end
      end
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
      %Q|<input type="text" name="#{ @id }" value="#{ escapeHTML @opt["default"].to_s }"#{ size }>|
   end
end
class FormFile < FormComponent
   def to_html
      %Q|<input type="file" name="#{ @id }"></input>|
   end
end
class FormSubmit < FormComponent
   def to_html
      %Q|<input type="submit" name="#{ @id }" value=""></input>|
   end
end

class FormBuilder
   include Enumerable
   def initialize( cgi, form_conf )
      @forms = []
      form_conf.each_with_index do |f, idx|
         klass = FormComponent.form2class( f )
         name = "form#{idx}"
         default = nil
         if cgi.valid?( name )
            f["default"] = cgi.value( name )
         end
         @forms << klass.new( name, f )
      end
   end
   def each
      @forms.each do |e|
         yield e
      end
   end
end

class RequiredFormMissingError < Exception; end

class ValidateError < Exception; end
class FilenameSuffixError < ValidateError; end

class FormCGI
   class Config
      def initialize( confio )
         @conf = YAML.load( confio )
      end
      def []( name )
         @conf[ name.to_s ]
      end
   end

   DATA_FILE = "data.csv"
   def initialize( cgi )
      @cgi = cgi
      @conf = Config.new( open("mformcgi.conf") )
      @forms =  FormBuilder.new( @cgi, @conf["forms"] )
      @rhtml = "index.rhtml"
   end
   def to_html
      do_eval_rhtml( @rhtml )
   end

   include ERB::Util
   def do_eval_rhtml( rhtml )
      ERB::new( open( "html/" + rhtml ).read, nil, "<>" ).result( binding )
   end
end

class FormCGIAdmin < FormCGI
   def initialize( cgi )
      super( cgi )
      @rhtml = "admin.rhtml"
   end
end

class FormCGISave < FormCGI
   def initialize( cgi )
      super( cgi )
      @rhtml = "save.rhtml"
      begin
         save
      rescue RequiredFormMissingError => e
         @rhtml = "index.rhtml"
         #STDERR.puts e.message
         @error_message = e.message
      rescue ValidateError => e
         @rhtml = "index.rhtml"
         #STDERR.puts e.message
         @error_message = e.message
      rescue FilenameSuffixError => e
         @rhtml = "index.rhtml"
         #STDERR.puts e.message
         @error_message = e.message
      end
   end

   def save
      time = Time.now.strftime("%Y%m%d%H%M%S")
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
            if form.filename_suffix and not Regexp.new( form.filename_suffix ) =~ str
               raise FilenameSuffixError, "validate error: #{form.label}:#{str}"
            end
            content = @cgi.value( form.id )
            #STDERR.puts content.inspect
            #STDERR.puts form.filename.inspect
            filename = nil
            eval( 'filename = "' + form.filename + '"', binding )
            #STDERR.puts filename.inspect
            open( File.join( @conf[:data_dir], filename ), "w" ) do |io|
               io.print content
            end
            str = original_filename
         else
            str = @cgi.value( form.id )
            #STDERR.puts form.id.inspect
            STDERR.puts form.validate.inspect
            STDERR.puts str.inspect
            if form.validate and not Regexp.new( form.validate ) =~ str
               raise ValidateError, "validate error: #{form.label}:#{str}"
            end
            if str and not str.empty?
               str.gsub( /\t/, " " ).delete( "\0" )
            end
         end
         @saved_data[ form.id ] = str
      end
      #STDERR.puts @forms.inspect
      #STDERR.puts @forms.map{|e| @saved_data[e.id] or "" }.inspect
      open( File.join( @conf[:data_dir], DATA_FILE ), "a" ) do |io|
         io.puts( ( [ time ] + @forms.map{|e| @saved_data[ e.id ] or "" } ).join("\t") )
      end
   end
end
