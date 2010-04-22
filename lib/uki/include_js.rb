require 'json'

module Uki
  
  INCLUDE_REGEXP = %r{((?:^|\n)[^\n]\W|^|\n)\s*include\s*\(\s*['"]([^"']+)["']\s*\)(?:\s*;)?(.*?\r?\n|$)}
  INCLUDE_STRING_REGEXP = %r{include_string\s*\(\s*['"]([^"']+)["']\s*\)}
  
  #
  # Preprocesses include() calls in js files
  def self.include_js path, included = {}, stack = []
    raise Exception.new("File #{path} not found.\nStack: #{stack.join(' -> ')}") unless File.exists?(path)
    path = File.expand_path path
    code, base = File.read(path), File.dirname(path)
    
    included[path] = true
    code.gsub(INCLUDE_REGEXP) do |match|
      if $1.include? '//' # include commented out 
        match
      else
        include_path = File.expand_path File.join(base, $2)
        unless included[include_path]
          $1 + include_js(include_path, included, stack + [include_path]) + $3
        else
          $1 + $3
        end
      end
    end.gsub(INCLUDE_STRING_REGEXP) do |match|
      include_string File.join(base, $1)
    end
  end
  
  def self.include_string path
    JSON.dump File.read(path)
  end
  
  def self.extract_includes path
    result = []
    File.read(path).scan(INCLUDE_REGEXP) do |match|
      result << $2 unless $1.include? '//' 
    end
    result
  end
  
  def self.append_include path, include_path
    count = extract_includes(path).size
    code = File.read(path)
    line_break = code.match(/\r\n/) ? "\r\n" : "\n"
    code = code.gsub(INCLUDE_REGEXP) do |match|
      next if $1.include? '//' 
      if (count -= 1) > 0
        match
      else
        ($3.length ? '' : line_break) + match + "include('#{include_path}');" + line_break
      end
    end
    File.open(path, 'w') { |f| f.write(code) }
  end
  
end