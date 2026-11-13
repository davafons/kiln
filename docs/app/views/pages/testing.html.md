# Testing

`Kiln::TestHelper` adds three Minitest helpers: `kiln_build` builds the whole site, `kiln_site` shares one build between the tests of a class, and `assert_page` renders one page the way a build does. It is not loaded with Kiln, so require it:

```ruby
# test/static_site_test.rb
require "test_helper"
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "the site builds repeatably" do
    kiln_build(repeatable: true) { |output| assert output.join("index.html").file? }
  end

  test "the home page has a heading" do
    assert_page "/", selector: "h1", text: "Welcome"
  end
end
```

## kiln_build

`kiln_build { |output| ... }` builds the site into a temporary directory and fails the test with the build report on any error. It yields the output as a `Pathname`, and removes the directory when the block returns.

With `repeatable: true` it builds twice and fails with the list of differing files. This catches pages that depend on the time, random values or ordering, which would make every deploy look like a change.

Without a block it returns the `Kiln::Build` and leaves the directory for the caller to remove.

A test build does not write `tmp/kiln-manifest.json`, so it does not change what the next `kiln:build` reports as changed.

## kiln_site

`kiln_site` returns the output of one build shared by every test in the class, as a `Pathname`. The first test that calls it builds the site into a temporary directory, which is removed when the test run ends. Use it when many tests read the built files, so the site is built once instead of once per test:

```ruby
class SiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "the sitemap lists the home page" do
    assert_includes kiln_site.join("sitemap.xml").read, "<loc>https://example.com/</loc>"
  end

  test "every post has a page" do
    Post.all.each { assert kiln_site.join("posts", it.slug, "index.html").file? }
  end
end
```

When the build fails, every test that calls `kiln_site` fails with the build report, and the site is not built again. Each test class gets its own build. Tests must not change the files, since later tests read the same directory.

## assert_page

`assert_page(path)` renders one path and asserts its status. `Kiln.building?` is true while it renders, and CSRF tokens are stripped. It returns the body.

| Option | What it does |
|---|---|
| `status:` | The expected status. The default is 200. |
| `selector:` | A CSS selector that must match. |
| `text:` | Text that one of the matched elements must contain. Needs `selector:`. |

```ruby
assert_page "/404", status: 404
body = assert_page "/blog", selector: "article h2", text: "Hello"
```

The helpers default to `Rails.application` and `Kiln.config`. Pass `app:` and `config:` to use others.
