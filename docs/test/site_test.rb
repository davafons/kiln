require "test_helper"

# Kiln's verifier already fails the build on a broken internal link, anchor or importmap module.
class SiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "every page is built, and the introduction is the home page" do
    kiln_build(repeatable: true) do |output|
      assert_includes output.join("index.html").read, "<h1"
      Docs::PAGES.filter_map(&:slug).each { assert output.join(it, "index.html").file?, "#{it} was not built" }
      assert_not output.join("introduction").exist?
      assert output.join("404.html").file?
      assert_includes output.join("llms.txt").read, "(https://kiln.davafons.com/):"
      assert_equal "kiln.davafons.com\n", output.join("CNAME").read
    end
  end

  test "the home page is the introduction" do
    assert_page "/", selector: "h1", text: "Introduction"
    assert_page "/", selector: "nav[aria-label=Documentation] [aria-current=page]", text: "Introduction"
  end

  test "a page has its title, navigation and contents" do
    assert_page "/pages", selector: "h1", text: "Pages"
    assert_page "/pages", selector: "nav[aria-label=Documentation] [aria-current=page]", text: "Pages"
    assert_page "/pages", selector: "nav[data-slot=toc] a[href='#value-lists']"
  end

  test "the sidebar links the introduction to the home page from any page" do
    assert_page "/pages", selector: "nav[aria-label=Documentation] a[href='/']", text: "Introduction"
  end

  test "the 404 page marks no page as current" do
    assert_not_includes assert_page("/404", status: 404), %(aria-current="page")
  end

  test "the installation page prints the version" do
    assert_page "/installation", selector: "p", text: "The current release is #{Kiln::VERSION}."
  end
end
