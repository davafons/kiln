require "test_helper"

# Randomized paths against the two places that turn a URL into a file. Uses the Minitest seed, so
# `bin/test --seed N` replays a failure.
class Kiln::PathSafetyTest < Kiln::TestCase
  ROUNDS = Integer(ENV.fetch("KILN_FUZZ_ROUNDS", 2000))
  PIECES = [ "a", "b.html", "index.html", ".", "..", "", "%2e", "%2E%2E", "%2F", "%00", "%", "%zz", "/", "//",
    "\\", "?q=1", "#x", "日本", "%E6%97%A5", " ", "+", "~", ".hidden", "a..b", "...", "x/../.." ].freeze

  setup { @random = Random.new(Minitest.seed) }

  def random_path
    "/" + Array.new(@random.rand(1..6)) { PIECES.sample(random: @random) }.join(@random.rand < 0.7 ? "/" : "")
  end

  test "the writer never writes outside the output" do
    root = tmp_output.join("site")
    writer = Kiln::Writer.new(root, mode: :directory, report: Kiln::Report.new)

    ROUNDS.times do
      path = random_path
      begin
        file = writer.write(path, %w[text/html text/plain application/json].sample(random: @random), "x")
      rescue Kiln::Error, SystemCallError
        next # Refused, or a file and a directory need the same name. Both stay inside the output.
      end
      target = root.join(file).expand_path.to_s
      assert target.start_with?("#{root.expand_path}/"), "#{path.inspect} wrote #{target}"
    end
    assert_equal [ "site" ], Dir.children(tmp_output)
  end

  test "the static resolver never returns a file outside the root" do
    root = tmp_output.join("site")
    root.join("a").mkpath
    root.join("index.html").write("home")
    root.join("a/index.html").write("a")
    tmp_output.join("secret.html").write("outside")
    tmp_output.join("index.html").write("outside")
    File.symlink(tmp_output.join("secret.html"), root.join("link.html"))
    resolver = Kiln::StaticResolver.new(root)
    real_root = "#{root.realpath}/"

    ROUNDS.times do
      path = random_path
      file = resolver.resolve(path)
      assert file.realpath.to_s.start_with?(real_root), "#{path.inspect} resolved to #{file.realpath}" if file
    end
    assert_nil resolver.resolve("/link.html"), "a symlink out of the root is not served"
  end
end
