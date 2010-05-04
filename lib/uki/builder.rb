require 'fileutils'
require 'tempfile'
require 'uki/include_js'

module Uki
  
  class Builder

    attr_accessor :path
    attr_accessor :options

    def initialize(path, options = {})
      @path = path
      @options = options
    end

    def code
      options[:compress] ? compressed_code : plain_code
    end

  protected
    def compressed_code
      unless @compressed_code
        code = Uki.include_js(path) do |path|
          if path.match(/.css$/)
            compiled_css path
          else
            File.read(path)
          end
        end
        Tempfile.open('w') { |file|
          file.write(code)
          file.flush
          @compressed_code = compiled_js(file.path)
        }
      end
      @compressed_code
    end

    def plain_code
      @plain_code ||= Uki.include_js path
    end

    def compiled_css path
      system "java -jar #{path_to_yui_compressor} #{path} > #{path}.tmp"
      code = File.read("#{path}.tmp")
      FileUtils.rm "#{path}.tmp"
      code
    end

    def compiled_js path
      system "java -jar #{path_to_google_compiler} --js #{path} > #{path}.tmp" 
      code = File.read("#{path}.tmp")
      FileUtils.rm "#{path}.tmp"
      code
    end

    def path_to_google_compiler
      File.join(UKI_ROOT, 'java', 'compiler.jar')
    end

    def path_to_yui_compressor
      File.join(UKI_ROOT, 'java', 'yuicompressor.jar')
    end
  end  
  
end
