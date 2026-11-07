module Kiln
  # Renders one path through the app's full Rack stack, the same way a browser request would.
  class Renderer
    TEXT_TYPE = %r{\Atext/|json|xml|javascript}

    def initialize(app, host:)
      @app = app
      @host = host
    end

    # Never follows redirects. App exceptions raise instead of rendering an error page.
    def get(path)
      response = raising_exceptions { Rack::MockRequest.new(@app).get(path, "HTTP_HOST" => @host, "HTTPS" => "on", "rack.url_scheme" => "https", "REMOTE_ADDR" => "127.0.0.1") }
      headers = response.headers.to_h.transform_keys(&:downcase)
      Response.new(path:, status: response.status, headers:, body: encode(response.body, headers["content-type"]))
    end

    private
      # Rails merges its env_config over the request env, so "action_dispatch.show_exceptions" can't be
      # set per request. Switch it on the app for the duration of the call instead.
      def raising_exceptions
        return yield unless @app.respond_to?(:env_config)

        config = @app.env_config
        previous = config["action_dispatch.show_exceptions"]
        config["action_dispatch.show_exceptions"] = :none
        begin
          yield
        ensure
          config["action_dispatch.show_exceptions"] = previous
        end
      end

      def encode(body, content_type)
        body = +body
        content_type.to_s.match?(TEXT_TYPE) ? body.force_encoding(Encoding::UTF_8) : body.force_encoding(Encoding::BINARY)
      end
  end
end
