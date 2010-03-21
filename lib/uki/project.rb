require 'fileutils'
require 'commander/import'
require 'erb'
require 'pathname'
require 'uki/include_js'

class Uki::Project
  attr_accessor :dest
  
  def initialize dest
    @dest = dest
  end
  
  def name
    File.basename File.expand_path(dest)
  end
  
  def create
    verify_empty
    init_dest
    copy_frameworks
    copy_templates
    copy_images
  end
  
  def build target, options = {}
    target = File.join(dest, target) unless Pathname.new(target).absolute?
    init_target target
    containers = find_containers
    cjs = extract_cjs(containers)
    build_containers containers, target, options
    build_js cjs, target, options
    build_images target, options
  end
  
  def create_class template, fullName
    path = fullName.split('.')
    create_packages path[0..-2]
    write_class template, path
  end

  protected
    def write_class template, path
      package_name = path[0..-2].join('.')
      class_name = path[-1]
      class_name = class_name[0,1].upcase + class_name[1..-1]
      file_name = class_name[0,1].downcase + class_name[1..-1]
      target = File.join *(path[0..-2] + [file_name])
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
  
    def build_js cjs, target, options
      cjs.each do |c|
        c = c.sub('.cjs', '.js')
        code = Uki.include_js File.join(dest, c)
        FileUtils.mkdir_p File.dirname(c)
        filename = File.join(target, c)
        File.open(filename, 'w') do |f|
          f.write code
        end
        compile_js filename if options[:compile]
      end
    end
    
    def compile_js file
      system "java -jar #{path_to_google_compiler} --js #{file} > #{file}.tmp" 
      FileUtils.rm file
      FileUtils.mv "#{file}.tmp", file
    end
  
    def build_containers containers, target, options
      containers.each do |c|
        code = File.read(c).gsub(%r{=\s*["']?([^"' ]+.cjs)}) do |match|
          match.sub('.cjs', '.js')
        end
        File.open(File.join(target, File.basename(c)), 'w') do |f|
          f.write code
        end
      end
    end
    
    def build_images target, options
      FileUtils.cp_r File.join(dest, 'i'), File.join(target, 'i')
    end
  
    def extract_cjs containers
      containers.map do |c|
        File.read(c).scan(%r{=\s*["']?([^"' ]+.cjs)})
      end.flatten.uniq
    end
    
    def find_containers
      Dir.glob File.join(dest, '*.html')
    end
    
    def init_target target
      FileUtils.rm_rf target
      FileUtils.mkdir_p target
    end
  
    def init_dest
      FileUtils.mkdir_p File.join(dest, project_name)
      ['view', 'model'].each do |name| 
        FileUtils.mkdir_p File.join(dest, project_name, name)
      end
    end
    
    def copy_templates
      File.open(File.join(dest, 'index.html'), 'w') do |f|
        f.write template('index.html').result(binding)
      end
      File.open(File.join(dest, "#{project_name}.js"), 'w') do |f|
        f.write template('myapp.js').result(binding)
      end
      File.open(File.join(dest, project_name, 'view.js'), 'w') do |f|
        package_name = "#{project_name}.view"
        f.write template('package.js').result(binding)
      end
      File.open(File.join(dest, project_name, 'model.js'), 'w') do |f|
        package_name = "#{project_name}.model"
        f.write template('package.js').result(binding)
      end
    end
    
    def project_name
      File.basename dest
    end
  
    def copy_frameworks
      FileUtils.mkdir_p File.join(dest, 'frameworks')
      frameworks_dest = File.join(dest, 'frameworks', 'uki')
      FileUtils.mkdir_p frameworks_dest
      FileUtils.cp_r File.join(path_to_uki_src, '.'), frameworks_dest
    end
    
    def template name
      path = File.join(UKI_ROOT, 'templates', "#{name}.erb")
      ERB.new File.read(path)
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
    
    def path_to_google_compiler
      File.join(UKI_ROOT, 'frameworks', 'uki', 'compiler.jar')
    end
  
end