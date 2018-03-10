module Grack
  class HandleErrorBadRequest
    ##
    # A shorthand for specifying a text content type for the Rack response.
    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    def self.response
      [400, PLAIN_TYPE, ["Bad Request"]]
    end

    def initialize(**)
    end

    def call(*)
      self.class.response
    end
  end
end
