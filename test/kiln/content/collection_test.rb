require "test_helper"
require "kiln/content"

class Kiln::Content::CollectionTest < Kiln::TestCase
  setup do
    Kiln::Content.reset!
    Kiln::Content.root = Pathname(__dir__).join("fixtures/content")
    Kiln::Content.show_drafts = false
  end

  teardown { Kiln::Content.reset! }

  test "all returns visible entries, newest first" do
    assert_equal %w[second first-post], blog.all.map(&:slug)
    assert_equal %w[second first-post], blog.map(&:slug)
  end

  test "entries" do
    post = blog.find("first-post")

    assert_equal "First post", post.title
    assert_equal Date.new(2024, 1, 10), post.published_at
    assert_equal %w[rails ruby], post.tags
    assert_equal %w[rails ruby], post[:tags]
    assert_equal "# Hello\n\nBody text.\n", post.body
    assert_includes post.html, %(<h1 id="hello">Hello</h1>)
    assert_predicate post.html, :html_safe?
    assert_equal "first-post", post.to_param
    assert_not post.draft?
    assert_raises(NoMethodError) { post.nope }
  end

  test "frontmatter published_at wins and title falls back to the slug" do
    post = blog.find("second")

    assert_equal Date.new(2024, 3, 1), post.published_at
    assert_equal "Second", post.title
    assert_equal :notes, post.category
  end

  test "drafts and scheduled entries are hidden" do
    assert_raises(Kiln::Content::NotFound) { blog.find("draft") }
    assert_raises(Kiln::Content::NotFound) { blog.find("future") }
    assert_nil blog.find_by(slug: "draft")
    assert_equal "second", blog.find_by(slug: "second").slug
  end

  test "show_drafts shows everything" do
    Kiln::Content.show_drafts = true

    assert_equal %w[future second draft first-post], blog.all.map(&:slug)
    assert blog.find("draft").draft?
  end

  test "show_drafts defaults to development only, never while building" do
    Kiln::Content.show_drafts = nil
    assert_not Kiln::Content.show_drafts

    Rails.env = "development"
    assert Kiln::Content.show_drafts
    Kiln.building! { assert_not Kiln::Content.show_drafts }
  ensure
    Rails.env = "test"
  end

  test "source positions count the frontmatter lines" do
    post = blog.find("first-post")
    assert_not_includes post.html, "data-tensaku-md"

    Kiln::Content.source_positions = true
    path = post.path.relative_path_from(Rails.root)
    assert_includes post.html, %(<h1 id="hello" data-tensaku-md="#{path}:5:1-5:7">)
    assert_includes post.html, %(<p data-tensaku-md="#{path}:7:1-7:10">Body text.</p>)
  end

  test "find with a preview token returns hidden entries" do
    token = blog.find_by(slug: "second").preview_token
    draft_token = Kiln::Content::Entry.new("blog", Kiln::Content.root.join("blog/2024-02-01-draft.md")).preview_token

    assert_equal "draft", blog.find("draft", preview_token: draft_token).slug
    assert_raises(Kiln::Content::NotFound) { blog.find("draft", preview_token: token) }
    assert_raises(Kiln::Content::NotFound) { blog.find("draft", preview_token: "") }
  end

  test "preview tokens are stable and depend on the secret" do
    token = blog.find("second").preview_token
    assert_equal token, Kiln::Content.collection("blog").find("second").preview_token

    Kiln::Content.preview_secret = "other"
    assert_not_equal token, blog.find("second").preview_token
  end

  test "NotFound maps to a 404" do
    assert_equal 404, ActionDispatch::ExceptionWrapper.status_code_for_exception("Kiln::Content::NotFound")
  end

  test "reloads when files change outside a build" do
    Kiln::Content.root = tmp_output
    tmp_output.join("notes").mkpath
    file = tmp_output.join("notes/a.md")
    file.write("one")

    assert_same Kiln::Content.collection("notes"), Kiln::Content.collection("notes")
    assert_equal "one", Kiln::Content.collection(:notes).find("a").body

    file.write("two")
    File.utime(Time.now, Time.now + 10, file)
    assert_equal "two", Kiln::Content.collection("notes").find("a").body

    tmp_output.join("notes/b.md").write("b")
    assert_equal %w[b a], Kiln::Content.collection("notes").map(&:slug)
  end

  test "memoizes in the build cache while building" do
    Kiln::Content.root = tmp_output
    tmp_output.join("notes").mkpath
    file = tmp_output.join("notes/a.md")
    file.write("one")

    Kiln.building! do
      assert_equal "one", Kiln::Content.collection("notes").find("a").body
      file.write("two")
      File.utime(Time.now, Time.now + 10, file)
      assert_equal "one", Kiln::Content.collection("notes").find("a").body
    end
  end

  test "works as a param source" do
    assert_equal [ { slug: "second" }, { slug: "first-post" } ], blog.map { { slug: it.slug } }
  end

  test "a missing directory is an empty collection" do
    assert_empty Kiln::Content.collection("nope").all
  end

  private
    def blog = Kiln::Content.collection("blog")
end
