module Kiln
  # What the app returned for one path.
  Response = Data.define(:path, :status, :headers, :body) do
    def content_type
      headers["content-type"].to_s.split(";").first.to_s.strip.downcase
    end

    def html? = content_type == "text/html"
    def success? = status.between?(200, 299)
    def redirect? = [ 301, 302, 303, 307, 308 ].include?(status)
    def location = headers["location"]
  end
end
