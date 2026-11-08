class PagesController < ApplicationController
  def home; end
  def about; end
  def guide; end
  def search; end
  def private_page; end
  def contact; end

  def health
    render json: { status: "ok", posts: Post.all.size }
  end

  # Built from other pages with Kiln.render, the way a search index is.
  def titles
    titles = [ about_path, guide_path ].to_h { [ it, Kiln.render(it)[%r{<h1[^>]*>(.*?)</h1>}m, 1] ] }
    render json: titles
  end

  def not_found
    render status: :not_found
  end
end
