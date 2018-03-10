module Grack
  class HandleErrorMethodNotAllowed
    ##
    # A shorthand for specifying a text content type for the Rack response.
    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    def self.response
      [405, PLAIN_TYPE, ["Method Not Allowed"]]
    end

    def initialize(**)
    end

    ##
    # Returns a Rack response appropriate for requests that use invalid verbs
    # for the requested resources.
    #
    # For HTTP 1.1 requests, a 405 code is returned.  For other versions, the
    # value from #bad_request is returned.
    #
    # @return a Rack response appropriate for requests that use invalid verbs
    #   for the requested resources.
    def call(env)
      if env["SERVER_PROTOCOL"] == "HTTP/1.1"
        self.class.response
      else
        HandleErrorBadRequest.response
      end
    end
  end
end
