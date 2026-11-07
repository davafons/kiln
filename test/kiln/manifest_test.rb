require "test_helper"

class Kiln::ManifestTest < Kiln::TestCase
  def manifest(pages)
    Kiln::Manifest.new.tap do |manifest|
      pages.each { |path, body| manifest.add(path, file: "#{path}.html", body:, content_type: "text/html") }
    end
  end

  test "entries are sorted with sha256 digests" do
    entries = manifest("/b" => "B", "/a" => "A").entries

    assert_equal %w[/a /b], entries.keys
    assert_equal({ content_type: "text/html", digest: Digest::SHA256.hexdigest("A"), file: "/a.html", noindex: false }, entries["/a"])
  end

  test "write is repeatable and round-trips through load" do
    first = manifest("/b" => "B", "/a" => "A")
    second = manifest("/a" => "A", "/b" => "B")

    assert_equal "kiln-manifest.json", first.write(tmp_output)
    written = tmp_output.join("kiln-manifest.json").read
    second.write(tmp_output)

    assert_equal written, tmp_output.join("kiln-manifest.json").read
    assert_equal first.entries, Kiln::Manifest.load(tmp_output.join("kiln-manifest.json")).entries
  end

  test "diff lists added, removed and changed paths" do
    old = manifest("/a" => "A", "/b" => "B", "/c" => "C")
    new = manifest("/a" => "A", "/b" => "B2", "/d" => "D")

    assert_equal({ added: %w[/d], removed: %w[/c], changed: %w[/b] }, old.diff(new))
  end
end
