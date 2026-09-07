module Prawnto
  module TemplateHandlers
    class Base

      def self.call(template, source = nil)
        source ||= template.source
        document_source = "_prawnto_compile_setup;" +
          "pdf = Prawn::Document.new(@prawnto_options[:prawn]);" +
          "#{source}\n" +
          "raw pdf.render;"

        return document_source unless template.respond_to?(:virtual_path) &&
          File.basename(template.virtual_path.to_s).start_with?('_')

        # A shared partial draws into its caller's document. Only the owning
        # template should serialize it; standalone partials still produce PDFs.
        "if defined?(@pdf) && @pdf.is_a?(Prawn::Document);" +
          "pdf = @pdf;" +
          "#{source}\n" +
          "raw '';" +
          "else;#{document_source}end;"
      end
    end
  end
end
