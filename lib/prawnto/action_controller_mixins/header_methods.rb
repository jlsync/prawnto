module Prawnto
  module ActionControllerMixin
    module HeaderMethods

      
      def set_headers
        compute_prawnto_options
    
        unless defined?(ActionMailer) && defined?(ActionMailer::Base) && self.is_a?(ActionMailer::Base)
          ssl = ssl_request?
          ie = ie_request? if ssl || !headers['Pragma'] || !headers['Cache-Control']
          set_pragma(ie, ssl)
          set_cache_control(ie, ssl)
          set_content_type
          set_disposition
          set_other_headers_for_ie_ssl(ie, ssl)
        end
      end

      private

      # TODO: kept around from railspdf-- maybe not needed anymore? should check.
      def ie_request?
        request.env['HTTP_USER_AGENT'] =~ /msie/i
      end

      # added to make ie happy with ssl pdf's (per naisayer)
      def ssl_request?
    		request.ssl?
      end

      def set_other_headers_for_ie_ssl(ie = ie_request?, ssl = ssl_request?)
        return unless ssl && ie
        headers['Content-Description'] = 'File Transfer'
        headers['Content-Transfer-Encoding'] = 'binary'
        headers['Expires'] = '0'        
      end

      # TODO: kept around from railspdf-- maybe not needed anymore? should check.
      def set_pragma(ie = ie_request?, ssl = ssl_request?)
        if ssl && ie
          headers['Pragma'] = 'public' # added to make ie ssl pdfs work (per naisayer)
        else
          headers['Pragma'] ||= ie ? 'no-cache' : ''
        end
      end

      # TODO: kept around from railspdf-- maybe not needed anymore? should check.
      def set_cache_control(ie = ie_request?, ssl = ssl_request?)
        if ssl && ie
          headers['Cache-Control'] = 'maxage=1' # added to make ie ssl pdfs work (per naisayer)
        else
          headers['Cache-Control'] ||= ie ? 'no-cache, must-revalidate' : ''
        end
      end

      def set_content_type
        response.content_type ||= Mime[:pdf]
      end

      def set_disposition
        inline = @prawnto_options[:inline] ? 'inline' : 'attachment'
        filename = @prawnto_options[:filename] ? "filename=\"#{@prawnto_options[:filename]}\"" : nil
        headers["Content-Disposition"] = [inline,filename].compact.join(';')
      end
    end
  end
end
