module Kiln
  # A plain in-memory store that returns the cached objects themselves (no copies), so memoized
  # repositories and collections keep their state for the whole build.
  class BuildCache
    def initialize
      @store = {}
      @mutex = Monitor.new
    end

    def fetch(key)
      @mutex.synchronize do
        return @store[key] if @store.key?(key)

        @store[key] = yield
      end
    end

    def read(key) = @mutex.synchronize { @store[key] }
    def write(key, value) = @mutex.synchronize { @store[key] = value }
    def delete(key) = @mutex.synchronize { @store.delete(key) }
    def clear = @mutex.synchronize { @store.clear }
  end
end
