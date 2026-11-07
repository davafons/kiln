module Kiln
  # Compares two directory trees byte for byte. Returns relative paths.
  module TreeDiff
    Result = Data.define(:added, :removed, :changed) do
      def empty? = added.empty? && removed.empty? && changed.empty?

      def to_s
        [ added.map { "+ #{it}" }, removed.map { "- #{it}" }, changed.map { "~ #{it}" } ].flatten.join("\n")
      end
    end

    def self.call(before, after)
      old_files = files(before)
      new_files = files(after)
      changed = (old_files & new_files).reject { FileUtils.identical?(File.join(before, it), File.join(after, it)) }
      Result.new(added: new_files - old_files, removed: old_files - new_files, changed:)
    end

    def self.files(root)
      return [] unless File.directory?(root)

      Dir.glob("**/*", File::FNM_DOTMATCH, base: root).reject { File.directory?(File.join(root, it)) }.sort
    end
  end
end
