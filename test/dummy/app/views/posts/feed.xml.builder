xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Dummy"
    xml.link "https://example.com/"
    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.link "https://example.com#{post_path(post.slug)}"
      end
    end
  end
end
