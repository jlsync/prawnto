module Prawnto
  module TemplateHandlers
    class Dsl < Base

      def self.call(template, source = nil)
        source ||= template.source
        super(template, "pdf.instance_eval do; #{source}\nend;")
      end

    end
  end
end
