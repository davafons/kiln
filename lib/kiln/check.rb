require "tmpdir"

module Kiln
  # Builds into a temp dir and compares the result with the committed output.
  class Check
    Result = Data.define(:report, :diff) do
      def success? = report.success? && diff.empty?
    end

    def initialize(app: Rails.application, config: Kiln.config)
      @app = app
      @config = config
    end

    def run
      Dir.mktmpdir("kiln-check") do |dir|
        report = Build.new(app: @app, config: @config, output: dir).run
        Result.new(report:, diff: TreeDiff.call(@config.output_path(@app.root), dir))
      end
    end
  end
end
