module Uki
  
  #
  # Preprocesses include() calls in js files
  def self.include_js(path, included = {}, stack = [])
    raise Exception.new("File #{path} not found.\nStack: #{stack.join(' -> ')}") unless File.exists?(path)
    
    code, base = File.read(path), File.dirname(path)
    
    code.gsub(%r{((?:^|\n)[^\n]\W|^|\n)include\s*\(\s*['"]([^"']+)["']\s*\)(\s*;)?}) do |match|
      if $1.include? '//' # include commented out 
        match
      else
        include_path = File.expand_path File.join(base, $2)
        unless included[include_path]
          included[include_path] = true
          $1 + include_js(include_path, included, stack + [include_path])
        else
          $1
        end
      end
    end
  end
  
end