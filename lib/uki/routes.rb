require 'uki/builder'

get %r{\.cjs$} do
  path = request.path.sub(/\.cjs$/, '.js').sub(%r{^/}, './')
  pass unless File.exists? path
  
  response.header['Content-type'] = 'application/x-javascript; charset=UTF-8'
  begin
    Uki::Builder.new(path, :optimize => false).code
  rescue Exception => e
    message = e.message.sub(/\n/, '\\n')
    "alert('#{message}')"
  end
end

get %r{.*} do
  path = request.path.sub(%r{^/}, './')
  path = File.join(path, 'index.html') if File.exists?(path) && File.directory?(path)
  p path
  pass unless File.exists?(path)
  send_file path
end
