module Grack
  class HandleErrorNotFound
    ##
    # A shorthand for specifying a text content type for the Rack response.
    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    ##
    # @return a Rack response for unlocatable resources.
    def self.response
      [404, PLAIN_TYPE, ["Not Found"]]
    end

    def initialize(**)
    end

    ##
    # @return a Rack response for unlocatable resources.
    def call(*)
      self.class.response
    end
  end
end
