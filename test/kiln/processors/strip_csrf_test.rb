require "test_helper"

class Kiln::Processors::StripCSRFTest < Kiln::TestCase
  FORMS = %(<%= form_with url: "/search", method: :post do |f| %><%= f.text_field :q %><% end %><%= button_to "Go", "/go" %>)

  test "leaves the page as Rails renders it with forgery protection off" do
    protected_html = render_forms(forgery_protection: true)
    assert_includes protected_html, %(name="authenticity_token")
    assert_includes protected_html, %(name="csrf-token")

    assert_equal render_forms(forgery_protection: false), Kiln::Processors::StripCSRF.call(protected_html)
  end

  test "strips tags in any attribute order" do
    html = %(<head><meta content="abc" name="csrf-token"></head><input value="x" name="authenticity_token" type="hidden">)

    assert_equal "<head></head>", Kiln::Processors::StripCSRF.call(html)
  end

  test "returns the input unchanged when nothing matches" do
    html = %(<head>\n  <meta name="viewport" content="width=device-width">\n</head><input name="q">)

    assert_equal html, Kiln::Processors::StripCSRF.call(html)
  end

  private
    def render_forms(forgery_protection:)
      previous = ApplicationController.allow_forgery_protection
      ApplicationController.allow_forgery_protection = forgery_protection
      ApplicationController.renderer.new("rack.session" => {}).render(inline: FORMS, layout: "application")
    ensure
      ApplicationController.allow_forgery_protection = previous
    end
end
