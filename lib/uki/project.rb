require 'fileutils'
require 'commander/import'
require 'erb'
require 'pathname'
require 'uki/builder'
require 'base64'
require 'digest/md5'

class Uki::Project
  CJS_REGEXP = %r{=\s*["']?(([^"' ]+).cjs)}
  
  attr_accessor :dest
  
  def initialize dest
    @dest = dest
  end
  
  # def name
  #   File.basename File.expand_path(dest)
  # end
  
  def name
    File.basename(File.expand_path(dest)).sub(/[^a-z0-9_$]+/, '_')
  end

  def create options
    verify_empty
    init_dest
    copy_frameworks
    copy_templates
    copy_images
    init_jspec if options[:jspec]
  end
  
  def build files, options = {}
    cjs = []
    containers = []
    files.each do |file|
      path = to_path(file)
      next unless File.exists?(path) 
      if file.match(/.html$/)
        cjs += extract_cjs(path)
        containers << path
      else
        cjs << path
      end
    end
    cjs.uniq!
    containers.uniq!
    
    output = to_path(options[:output])
    FileUtils.rm_rf output if options[:clean_output]
    FileUtils.mkdir_p output
    
    cjs.each do |path|
      File.open(File.join(output, File.basename(path)), 'w') do |f|
        f.write( Uki::Builder.new(path, :compress => options[:compress]).code )
      end
    end
    
    build_containers containers, output
    build_images output if options[:images]
  end
  
  def create_class template, fullName
    path = fullName.split('.')
    create_packages path[0..-2]
    write_class template, path
  end

  def create_function template, fullName
    path = fullName.split('.')
    create_packages path[0..-2]
    write_function template, path
  end
  
  def ie_images target
    contents = File.read(File.join(dest, target))
    place = File.join(dest, 'tmp', 'theme')
    # button-full/normal-v.png
    contents.scan(%r{\[[^"]*"([^"]+)"[^"]+"data:image/png;base64,([^"]+)"[^"\]]*(?:"([^"]+)"[^"\]]*)?\]}) do
      p $1
      file = File.join(place, $1)
      FileUtils.mkdir_p File.dirname(file)
      File.open(file, 'w') do |f| 
        f.write Base64.decode64($2)
      end
      `convert #{File.join(place, $1)} #{File.join(place, $3)}` if $3
    end
    place
  end
  
  protected
    def to_path file
      Pathname.new(file).absolute? ? file : File.join(dest, file)
    end
  
    def write_class template, path
      package_name = path[0..-2].join('.')
      class_name   = path[-1]
      class_name   = class_name[0,1].upcase + class_name[1..-1]
      file_name    = class_name[0,1].downcase + class_name[1..-1]
      target       = File.join( *(path[0..-2] + [file_name]) )
      target += '.js'
      File.open(File.join(dest, target), 'w') do |f|
        f.write template(template).result(binding)
      end
      add_include(target)
    end
    
    def write_function template, path
      package_name  = path[0..-2].join('.')
      function_name = path[-1]
      function_name = function_name[0,1].downcase + function_name[1..-1]
      file_name     = function_name
      target        = File.join( *(path[0..-2] + [file_name]) )
      target += '.js'
      File.open(File.join(dest, target), 'w') do |f|
        f.write template(template).result(binding)
      end
      add_include(target)
    end
  
    def add_include path
      target = File.join(dest, "#{name}.js")
      includes = Uki.extract_includes target
      unless includes.include? path
        Uki.append_include(target, path)
      end
    end
    
    def create_packages path
      current = []
      path.each do |dir|
        current << dir
        package_name = current.join('.')
        target = File.join(dest, *current)
        FileUtils.mkdir_p target unless File.exists?(target)
        unless File.exists?("#{target}.js")
          File.open("#{target}.js", 'w') do |f|
            f.write template('package.js').result(binding)
          end
        end
      end
    end
  
    def build_containers containers, output
      containers.each do |c|
        code = File.read(c).gsub(CJS_REGEXP) do |match|
          md5 = Digest::MD5.file(File.join(output, "#{$2}.js")).hexdigest
          match.sub('.cjs', ".js?#{md5}")
        end
        File.open(File.join(output, File.basename(c)), 'w') do |f|
          f.write code
        end
      end
    end
    
    def build_images output
      FileUtils.cp_r File.join(dest, 'i'), File.join(output, 'i')
    end
  
    def extract_cjs container
      File.read(container).scan(CJS_REGEXP).map { |match| match[0].sub('.cjs', '.js') }
    end
    
    def init_dest
      FileUtils.mkdir_p File.join(dest, name)
      ['view', 'model', 'layout', 'controller'].each do |n| 
        FileUtils.mkdir_p File.join(dest, name, n)
      end
    end
    
    def copy_templates
      File.open(File.join(dest, 'index.html'), 'w') do |f|
        f.write template('index.html').result(binding)
      end
      File.open(File.join(dest, "#{name}.js"), 'w') do |f|
        f.write template('myapp.js').result(binding)
      end
      
      create_function 'layout.js', "#{name}.layout.main"
      
      ['view', 'model', 'layout', 'controller'].each do |n|
        File.open(File.join(dest, name, "#{n}.js"), 'w') do |f|
          package_name = "#{name}.#{n}"
          f.write template('package.js').result(binding)
        end
      end
      
    end
    
    def copy_frameworks
      FileUtils.mkdir_p File.join(dest, 'frameworks')
      frameworks_dest = File.join(dest, 'frameworks', 'uki')
      FileUtils.mkdir_p frameworks_dest
      FileUtils.cp_r File.join(path_to_uki_src, '.'), frameworks_dest
    end
    
    def init_jspec
      FileUtils.mkdir_p File.join(dest, 'spec')
      FileUtils.cp_r path_to_jspec_lib, File.join(dest, 'frameworks', 'jspec')
      
      File.open(File.join(dest, 'spec.html'), 'w') do |f|
        f.write template('spec.html').result(binding)
      end
      File.open(File.join(dest, 'spec', 'spec.js'), 'w') do |f|
        f.write template('spec.js').result(binding)
      end
    end
    
    def template name
      path = File.join(UKI_ROOT, 'templates', "#{name}.erb")
      ERB.new File.read(path)
    end
    
    def path_to_jspec_lib
      File.join(UKI_ROOT, 'frameworks', 'jspec', 'lib')
    end
    
    def path_to_uki_src
      File.join(UKI_ROOT, 'frameworks', 'uki', 'src')
    end
    
    def images_path
      File.join(path_to_uki_src, 'uki-theme', 'airport', 'i')
    end
  
    def verify_empty
      unless Dir[dest + '/*'].empty?
        abort unless agree "`#{dest}' is not empty; continue? "
      end
    end
    
    def copy_images
      FileUtils.cp_r images_path, File.join(dest, 'i')
    end
    
end