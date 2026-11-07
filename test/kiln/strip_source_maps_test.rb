require "test_helper"

class Kiln::StripSourceMapsTest < Kiln::TestCase
  test "removes JavaScript source map comments" do
    assert_equal "console.log(1);\n", Kiln::Processors::StripSourceMaps.call("console.log(1);\n//# sourceMappingURL=app.js.map\n")
    assert_equal "a();", Kiln::Processors::StripSourceMaps.call("a();//# sourceMappingURL=a.js.map")
  end

  test "removes CSS source map comments" do
    assert_equal "body{}\n", Kiln::Processors::StripSourceMaps.call("body{}\n/*# sourceMappingURL=app.css.map */\n")
  end

  test "leaves other comments alone" do
    text = "// a comment\n/* another */\nbody{}\n"
    assert_equal text, Kiln::Processors::StripSourceMaps.call(text)
  end
end
