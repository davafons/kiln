require "digest"
require "json"

module Kiln
  # Every page written by a build: path => file, content digest, content type and noindex flag.
  class Manifest
    FILENAME = "kiln-manifest.json"

    def self.load(file)
      new(JSON.parse(File.read(file)).transform_values(&:symbolize_keys))
    end

    def initialize(entries = {})
      @entries = entries
      @mutex = Mutex.new
    end

    def add(path, file:, body:, content_type:, noindex: false)
      entry = { content_type:, digest: Digest::SHA256.hexdigest(body), file: file.to_s, noindex: }
      @mutex.synchronize { @entries[path] = entry }
    end

    def entries
      @entries.sort.to_h { |path, entry| [ path, entry.sort.to_h ] }
    end

    def write(output)
      File.write(Pathname(output).join(FILENAME), "#{JSON.pretty_generate(entries)}\n")
      FILENAME
    end

    # Changes from this manifest to `other` (old.diff(new)).
    def diff(other)
      mine = entries
      theirs = other.entries
      {
        added: theirs.keys - mine.keys,
        removed: mine.keys - theirs.keys,
        changed: (mine.keys & theirs.keys).reject { mine[it][:digest] == theirs[it][:digest] }
      }
    end
  end
end
