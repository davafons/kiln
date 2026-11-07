module Kiln
  # One concrete path to render. `route_name` is the Rails route name (nil for unnamed routes).
  Page = Data.define(:path, :route_name, :params) do
    def initialize(path:, route_name: nil, params: {})
      super
    end
  end
end
