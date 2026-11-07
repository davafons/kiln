module Kiln
  # A plain in-memory store that returns the cached objects themselves (no copies), so memoized
  # repositories and collections keep their state for the whole build. Outside a build, fetch runs
  # the block every time, so a development server never serves stale data.
  class BuildCache
    def initialize
      @store = {}
      @mutex = Monitor.new
    end

    def fetch(key)
      return yield unless Kiln.building?

      @mutex.synchronize do
        return @store[key] if @store.key?(key)

        @store[key] = yield
      end
    end

    def clear = @mutex.synchronize { @store.clear }
  end
end
