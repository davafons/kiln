require "test_helper"

class Kiln::LinksTest < Kiln::TestCase
  test "reads href, src and every srcset candidate" do
    img = Nokogiri::HTML5.fragment(%(<img src="/a.png" srcset="/a-1x.png 1x, /a-2x.png 2x">)).at_css("img")
    assert_equal %w[/a.png /a-1x.png /a-2x.png], Kiln::Links.in(img)
  end

  test "reads importmap imports and scopes" do
    json = %({"imports":{"app":"/assets/app.js"},"scopes":{"/x/":{"a":"/assets/a.js"}}})
    assert_equal %w[/assets/app.js /assets/a.js], Kiln::Links.importmap(json)
  end

  test "an invalid importmap gives nil" do
    assert_nil Kiln::Links.importmap("{")
    assert_nil Kiln::Links.importmap("[]")
    assert_nil Kiln::Links.importmap(%({"imports":{"a":1}}))
  end
end
