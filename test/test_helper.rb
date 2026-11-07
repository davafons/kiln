# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require "tmpdir"

module Kiln
  class TestCase < ActiveSupport::TestCase
    # A fresh temp dir per test, removed afterwards.
    def tmp_output
      @tmp_output ||= Pathname(Dir.mktmpdir("kiln-test"))
    end

    teardown { FileUtils.rm_rf(@tmp_output) if @tmp_output }

    def dummy_app = Rails.application

    # Replaces a module method for the block, such as Kiln::Processors::StripCSRF.call, to observe or
    # change what a build renders.
    def replace_method(object, name, replacement)
      original = object.method(name)
      object.define_singleton_method(name, &replacement)
      yield
    ensure
      object.define_singleton_method(name, original)
    end
  end
end
