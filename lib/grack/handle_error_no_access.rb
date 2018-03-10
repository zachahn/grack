module Grack
  class HandleErrorNoAccess
    ##
    # A shorthand for specifying a text content type for the Rack response.
    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    ##
    # @return a Rack response for forbidden resources.
    def self.response
      [403, PLAIN_TYPE, ["Forbidden"]]
    end

    def initialize(**)
    end

    ##
    # @return a Rack response for forbidden resources.
    def call(*)
      self.class.response
    end
  end
end
