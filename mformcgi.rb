#!/usr/bin/env ruby
# $Id: mformcgi.rb,v 1.10 20

require "erb"
require "yaml"
require "cgi"

class CGI
   def valid?( param )
      params[param] and params[param][0] and params[param][0].size > 0
   end
   def value( opt, i = 0 )
      @data ||= {}
      if @data[opt]
         @data[opt]
      else
         if i.nil?
            data = params[opt]
         else
            data = params[opt][i]
         end
         #STDERR.puts data.inspect
         if data.nil?
            nil
         elsif multipart? and data.original_filename.empty?
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
      when "textarea"
         FormTextarea
      when "checkbox"
         FormCheckbox
      when "radio"
         FormRadio
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
class FormTextarea < FormComponent
   def to_html
      rows = @opt["rows"] ? %Q| rows="#{ @opt["rows"].to_i }"| : ""
      cols = @opt["cols"] ? %Q| cols="#{ @opt["cols"].to_i }"| : ""
      %Q|<textarea#{rows}#{cols}>#{ escapeHTML @opt["default"].to_s }</textarea>|
   end
end
class FormRadio < FormComponent
   def to_html
      str = []
      @opt["choice"].each do |e|
         str << %Q|<label><input type="radio" name="#{ @id }" value="#{ escapeHTML e }">#{ escapeHTML e }</input></label>|
      end
      str.join("\n")
   end
end
class FormCheckbox < FormComponent
   def to_html
      str = []
      @opt["choice"].each do |e|
         str << %Q|<label><input type="checkbox" name="#{ @id }" value="#{ escapeHTML e }">#{ escapeHTML e }</input></label>|
      end
      str.join("\n")
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

class FormCGIError < Exception
   attr_reader :form, :default_message
   def initialize( msg = nil, form = nil )
      super( msg )
      @form = form
      @default_message = self.to_s
   end
end
class RequiredFormMissingError < FormCGIError
   def initialize( msg = nil, form = nil )
      super( msg, form )
      @defaule_message = "missing form value"
   end
end
class ValidateError < FormCGIError
   def initialize( msg = nil, form = nil )
      super( msg, form )
      @defaule_message = "validate error"
   end
end
class FilenameSuffixError < FormCGIError
   def initialize( msg = nil, form = nil )
      super( msg, form )
      @defaule_message = "validate error"
   end
end

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
         #STDERR.puts e.message.inspect
         #STDERR.puts e.class.to_s
         @error = e
      rescue ValidateError => e
         @rhtml = "index.rhtml"
         #STDERR.puts e.message
         @error = e
      rescue FilenameSuffixError => e
         @rhtml = "index.rhtml"
         #STDERR.puts e.message
         @error = e
      end
   end

   def save
      @time = Time.now.strftime("%Y%m%d%H%M%S")
      @saved_data = {}
      @forms.each do |form|
         str = @cgi.value( form.id )
         if str.nil? or str.size == 0 and form.require?
            raise RequiredFormMissingError.new( form.label, form )
         end
         #STDERR.puts form.class
         if form.class == FormFile
            original_filename = str.original_filename
            extname = File.extname( original_filename )
            if form.filename_suffix and not Regexp.new( form.filename_suffix ) =~ original_filename
               raise FilenameSuffixError.new( "#{form.label}:#{original_filename}", form )
            end
            content = str.read
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
            #STDERR.puts form.validate.inspect
            #STDERR.puts str.inspect
            if form.validate and not Regexp.new( form.validate ) =~ str
               raise ValidateError.new( "#{form.label}:#{str}", form )
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
         io.puts( ( [ @time ] + @forms.map{|e| @saved_data[ e.id ] or "" } ).join("\t") )
      end
   end

   def error_message
      form = @error.form
      str =
         if form and form.message and form.message[@error.class.to_s]
            form.message[@error.class.to_s]
         elsif @conf["message"] and @conf["message"][@error.class.to_s]
            @conf["message"][@error.class.to_s]
         else
            @error.default_message
         end
      str << ": #{@error.message}" if @error.message and not @error.message.empty?
   end
end
