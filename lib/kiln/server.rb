require "rack/mime"

module Kiln
  # Rack app that serves the built output the way a static host would.
  class Server
    def self.start(root, port:)
      require "rackup"
      Rackup::Handler.default.run(new(root), Host: "localhost", Port: port)
    end

    def initialize(root)
      @root = Pathname(root)
      @resolver = StaticResolver.new(@root)
      @redirects = Redirects.load(@root.join(Redirects::FILENAME)).index_by(&:from)
    end

    def call(env)
      path = env["PATH_INFO"].presence || "/"

      if (redirect = @redirects[path])
        [ redirect.status, { "location" => redirect.to }, [] ]
      elsif (file = @resolver.resolve(path))
        serve(200, file)
      elsif (not_found = @resolver.resolve("/404.html"))
        serve(404, not_found)
      else
        [ 404, { "content-type" => "text/plain" }, [ "Not found\n" ] ]
      end
    end

    private
      def serve(status, file)
        body = file.binread
        type = Rack::Mime.mime_type(file.extname, "application/octet-stream")
        [ status, { "content-type" => type, "content-length" => body.bytesize.to_s }, [ body ] ]
      end
  end
end
