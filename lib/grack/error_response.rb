module Grack
  module ErrorResponse
    module_function

    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    ##
    # @return a Rack response for generally bad requests.
    def bad_request
      [400, PLAIN_TYPE, ["Bad Request"]]
    end

    ##
    # @return a Rack response for unlocatable resources.
    def not_found
      [404, PLAIN_TYPE, ["Not Found"]]
    end

    ##
    # @return a Rack response for forbidden resources.
    def no_access
      [403, PLAIN_TYPE, ["Forbidden"]]
    end
  end
end
