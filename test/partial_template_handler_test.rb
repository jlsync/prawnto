require 'minitest/autorun'
require 'prawn'
require 'action_view'
require_relative '../lib/prawnto/action_view_mixin'
require_relative '../lib/prawnto/template_handlers/base'
require_relative '../lib/prawnto/template_handlers/dsl'

class PartialTemplateHandlerTest < Minitest::Test
  Template = Struct.new(:source, :virtual_path)

  class Controller
    attr_reader :header_calls

    def initialize
      @header_calls = 0
    end

    def set_headers
      @header_calls += 1
    end

    def prawnto_options
      { :prawn => { :page_size => 'A5', :print_scaling => :none } }
    end
  end

  class View
    include Prawnto::ActionViewMixin
    include ActionView::Helpers::OutputSafetyHelper
    attr_reader :controller, :documents_seen

    def initialize(handler)
      @controller = Controller.new
      @handler = handler
      @documents_seen = []
    end

    def evaluate(source, path, supplied_source = nil)
      instance_eval(@handler.call(Template.new(source, path), supplied_source))
    end

    def draw_part
      evaluate('pdf.text "Attendee"', 'badges/_part')
    end

    def draw_badge
      evaluate('2.times { draw_part }', 'badges/_badge')
    end
  end

  def setup
    @documents = []
    @render_calls = Hash.new(0)
    documents = @documents
    render_calls = @render_calls
    @original_new = Prawn::Document.method(:new)
    original_new = @original_new
    Prawn::Document.define_singleton_method(:new) do |*args, &block|
      document = original_new.call(*args, &block)
      documents << document
      original_render = document.method(:render)
      document.define_singleton_method(:render) do |*render_args|
        render_calls[self] += 1
        original_render.call(*render_args)
      end
      document
    end
  end

  def teardown
    Prawn::Document.define_singleton_method(:new, @original_new)
  end

  def assert_pdf(result)
    assert result.start_with?('%PDF-')
    assert result.html_safe?
    assert_includes result, '/PrintScaling /None'
  end

  def test_rails_collection_style_nested_partials_share_one_document
    view = View.new(Prawnto::TemplateHandlers::Base)
    result = view.evaluate('@pdf = pdf; 3.times { draw_badge }', 'badges/show')

    assert_equal 1, @documents.size
    assert_equal 1, @render_calls.values.sum
    assert_equal 1, view.controller.header_calls
    assert_pdf result
    # Six real text operations reached the final shared PDF.
    assert_equal 6, result.scan(/ T[Jj]\b/).size
  end

  [Prawnto::TemplateHandlers::Base, Prawnto::TemplateHandlers::Dsl].each do |handler|
    kind = handler.name.split('::').last.downcase
    body = handler == Prawnto::TemplateHandlers::Dsl ? 'text "Shared text"' : 'pdf.text "Shared text"'

    define_method("test_#{kind}_partial_draws_into_shared_document_without_serializing") do
      view = View.new(handler)
      document = Prawn::Document.new
      document.text 'Existing text'
      view.instance_variable_set(:@pdf, document)

      result = view.evaluate(body, 'badges/_part')

      assert_equal '', result
      assert result.html_safe?
      assert_equal [document], @documents
      assert_equal 0, @render_calls.values.sum
      assert_equal 0, view.controller.header_calls
      assert_equal 2, document.render.scan(/ T[Jj]\b/).size
    end

    define_method("test_#{kind}_standalone_partial_still_renders_a_pdf") do
      view = View.new(handler)
      result = view.evaluate(body, 'badges/_part')

      assert_pdf result
      assert_equal 1, @documents.size
      assert_equal 1, @render_calls.values.sum
      assert_equal 1, view.controller.header_calls
    end

    define_method("test_#{kind}_non_pdf_instance_variable_does_not_enable_sharing") do
      view = View.new(handler)
      view.instance_variable_set(:@pdf, 'unrelated value')

      assert_pdf view.evaluate(body, 'badges/_part')
      assert_equal 1, @documents.size
      assert_equal 1, @render_calls.values.sum
    end

    define_method("test_#{kind}_top_level_render_remains_independent_of_existing_document") do
      view = View.new(handler)
      previous = Prawn::Document.new
      view.instance_variable_set(:@pdf, previous)

      assert_pdf view.evaluate(body, 'badges/_folder/show')
      assert_equal 2, @documents.size
      assert_equal 0, @render_calls[previous]
      assert_equal 1, @render_calls.values.sum
    end

    define_method("test_#{kind}_inline_template_remains_a_document") do
      view = View.new(handler)
      assert_pdf view.evaluate(body, nil)
      assert_equal 1, @documents.size
      assert_equal 1, @render_calls.values.sum
    end

    define_method("test_#{kind}_uses_source_supplied_by_rails") do
      view = View.new(handler)
      assert_pdf view.evaluate('raise "outdated template source"', 'badges/show', body)
    end

    define_method("test_#{kind}_shared_partial_propagates_errors_without_serializing") do
      view = View.new(handler)
      document = Prawn::Document.new
      view.instance_variable_set(:@pdf, document)

      error = assert_raises(RuntimeError) { view.evaluate('raise "invalid badge"', 'badges/_part') }

      assert_equal 'invalid badge', error.message
      assert_equal [document], @documents
      assert_equal 0, @render_calls.values.sum
    end
  end
end
