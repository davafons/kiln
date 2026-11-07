require "test_helper"

# Kiln's verifier already fails the build on a broken internal link, anchor or importmap module.
class SiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "every page is built" do
    kiln_build(repeatable: true) do |output|
      assert output.join("index.html").file?
      Docs::PAGES.each { assert output.join(it.slug, "index.html").file?, "#{it.slug} was not built" }
      assert output.join("404.html").file?
      assert output.join("llms.txt").file?
      assert_equal "kiln.davafons.com\n", output.join("CNAME").read
    end
  end

  test "a page has its title, navigation and contents" do
    assert_page "/pages", selector: "h1", text: "Declaring pages"
    assert_page "/pages", selector: "nav[aria-label=Documentation] [aria-current=page]", text: "Declaring pages"
    assert_page "/pages", selector: "nav[data-slot=toc] a[href='#value-lists']"
  end

  test "the installation page prints the version" do
    assert_page "/installation", selector: "p", text: "The current release is #{Kiln::VERSION}."
  end
end
