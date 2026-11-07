require "test_helper"
require "kiln/content"

class Kiln::Content::FrontmatterTest < Kiln::TestCase
  test "splits YAML frontmatter from the body" do
    attributes, body = Kiln::Content::Frontmatter.parse("---\ntitle: Hi\ndate: 2024-01-02\nkind: :note\n---\n# Body\n")

    assert_equal({ "title" => "Hi", "date" => Date.new(2024, 1, 2), "kind" => :note }, attributes)
    assert_equal "# Body\n", body
  end

  test "text without frontmatter is all body" do
    assert_equal [ {}, "# Body\n---\n" ], Kiln::Content::Frontmatter.parse("# Body\n---\n")
  end

  test "empty frontmatter" do
    assert_equal [ {}, "Body" ], Kiln::Content::Frontmatter.parse("---\n---\nBody")
  end

  test "refuses unsafe YAML" do
    assert_raises(Psych::DisallowedClass) { Kiln::Content::Frontmatter.parse("---\nx: !ruby/object:Object {}\n---\n") }
  end
end
