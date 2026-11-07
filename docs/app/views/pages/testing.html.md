# Testing

`Kiln::TestHelper` adds two Minitest helpers: one builds the whole site, the other renders a single page the way a build does. It is not loaded with Kiln, so require it from the test:

```ruby
# test/static_site_test.rb
require "test_helper"
require "kiln/test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  include Kiln::TestHelper

  test "the site builds repeatably" do
    kiln_build(repeatable: true) { |output| assert output.join("index.html").file? }
  end

  test "home page" do
    assert_page "/", selector: "h1", text: "Welcome"
  end
end
```

## kiln_build

`kiln_build { |output| ... }` builds the site into a temporary directory and fails the test with the build report when there is any error. It yields the output path as a `Pathname`, and removes the directory when the block returns.

With `repeatable: true` it builds twice, fails with the list of differing files when the two outputs differ, and yields the first output. That catches pages whose output depends on the time, random values or ordering, which would make every deploy look like a change.

Without a block, it returns the `Kiln::Build` and leaves the temporary directory for the caller to remove. `app:` and `config:` default to `Rails.application` and `Kiln.config`.

A test build does not write `tmp/kiln-manifest.json`, so it never changes what the next `kiln:build` reports as changed.

## assert_page

`assert_page(path)` renders one path through the app and asserts it responds with 200. CSRF tokens are stripped and `Kiln.building?` is true while it renders, as in a build. It returns the body.

| Option | What it does |
|---|---|
| `status:` | The expected status. Defaults to 200. |
| `selector:` | A CSS selector that must match. |
| `text:` | Text that one of the matched elements must contain. Needs `selector:`. |

```ruby
assert_page "/404", status: 404
body = assert_page "/blog", selector: "article h2", text: "Hello"
```

## This site's test

The docs app has one test, which builds the whole site twice and checks every page in the page list:

```ruby
test "every page is built" do
  kiln_build(repeatable: true) do |output|
    Docs::PAGES.each { assert output.join(it.slug, "index.html").file? }
  end
end
```

The repository's CI runs it, and also builds the site with `RAILS_ENV=production bin/rails kiln:build`, so a change to Kiln that breaks this site fails CI.
