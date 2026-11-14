require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext/class/attribute'
require 'action_dispatch'
require_relative '../lib/prawnto/action_controller_mixin'

class HeaderAndOptionsTest < Minitest::Test
  class CountingRequest
    attr_reader :env

    def initialize(user_agent: nil, ssl: false)
      @env = user_agent ? { 'HTTP_USER_AGENT' => user_agent } : {}
      @ssl = ssl
    end

    def ssl?
      @ssl
    end
  end

  class BaseController
    include Prawnto::ActionControllerMixin

    attr_accessor :request

    def initialize(request = CountingRequest.new)
      @request = request
      @response = Struct.new(:content_type, :headers).new(nil, {})
    end

    def response
      @response
    end

    def headers
      @response.headers
    end

    private

    def ie_request?
      @ie_calls = (@ie_calls || 0) + 1
      super
    end

    def ssl_request?
      @ssl_helper_calls = (@ssl_helper_calls || 0) + 1
      super
    end

    public

    def ie_helper_calls
      @ie_calls || 0
    end

    def ssl_helper_calls
      @ssl_helper_calls || 0
    end
  end

  class ConfiguredController < BaseController
    prawnto :inline => false, :filename => 'report.pdf', :prawn => { :page_size => 'A4', :margin => 20 }
  end

  class NilHashesController < BaseController
    self.prawn_hash = nil
    self.prawnto_hash = nil
  end

  def setup
    unless defined?(Mime) && Mime[:pdf]
      Mime::Type.register('application/pdf', :pdf) if defined?(Mime::Type)
    end
  end

  def test_non_ie_non_ssl_sets_headers_and_checks_request_once
    controller = BaseController.new(CountingRequest.new(user_agent: 'Mozilla/5.0', ssl: false))
    controller.set_headers

    assert_equal '', controller.headers['Pragma']
    assert_equal '', controller.headers['Cache-Control']
    assert_equal 'inline', controller.headers['Content-Disposition']
    assert_equal 1, controller.ssl_helper_calls
    assert_equal 1, controller.ie_helper_calls
  end

  def test_ie_non_ssl_sets_no_cache_headers_and_checks_request_once
    controller = BaseController.new(CountingRequest.new(user_agent: 'Mozilla/4.0 (compatible; MSIE 8.0)', ssl: false))
    controller.set_headers

    assert_equal 'no-cache', controller.headers['Pragma']
    assert_equal 'no-cache, must-revalidate', controller.headers['Cache-Control']
    assert_nil controller.headers['Content-Description']
    assert_equal 1, controller.ssl_helper_calls
    assert_equal 1, controller.ie_helper_calls
  end

  def test_ie_ssl_sets_ie_ssl_headers_and_checks_request_once
    controller = BaseController.new(CountingRequest.new(user_agent: 'MSIE 9.0', ssl: true))
    controller.set_headers

    assert_equal 'public', controller.headers['Pragma']
    assert_equal 'maxage=1', controller.headers['Cache-Control']
    assert_equal 'File Transfer', controller.headers['Content-Description']
    assert_equal 'binary', controller.headers['Content-Transfer-Encoding']
    assert_equal '0', controller.headers['Expires']
    assert_equal 1, controller.ssl_helper_calls
    assert_equal 1, controller.ie_helper_calls
  end

  def test_preset_headers_skip_ie_check_on_non_ssl
    controller = BaseController.new(CountingRequest.new(user_agent: 'MSIE 9.0', ssl: false))
    controller.headers['Pragma'] = 'private'
    controller.headers['Cache-Control'] = 'max-age=60'
    controller.set_headers

    assert_equal 'private', controller.headers['Pragma']
    assert_equal 'max-age=60', controller.headers['Cache-Control']
    assert_equal 1, controller.ssl_helper_calls
    assert_equal 0, controller.ie_helper_calls
  end

  def test_direct_private_header_methods_still_work_without_args
    controller = BaseController.new(CountingRequest.new(user_agent: 'MSIE 9.0', ssl: true))
    controller.send(:set_pragma)
    controller.send(:set_cache_control)
    controller.send(:set_other_headers_for_ie_ssl)

    assert_equal 'public', controller.headers['Pragma']
    assert_equal 'maxage=1', controller.headers['Cache-Control']
    assert_equal '0', controller.headers['Expires']
  end

  def test_options_manager_with_empty_nil_and_merged_class_options
    empty_controller = BaseController.new
    assert_equal({ :inline => true, :prawn => {} }, empty_controller.send(:compute_prawnto_options))

    nil_controller = NilHashesController.new
    assert_equal({ :inline => true, :prawn => {} }, nil_controller.send(:compute_prawnto_options))

    configured = ConfiguredController.new
    configured.prawnto(:inline => true, :prawn => { :page_size => 'LETTER' })
    assert_equal(
      {
        :inline => true,
        :filename => 'report.pdf',
        :prawn => { :page_size => 'LETTER', :margin => 20 },
      },
      configured.send(:compute_prawnto_options),
    )
  end
end
