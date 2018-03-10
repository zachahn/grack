module Grack
  class HandlePack
    ##
    # A list of supported pack service types.
    VALID_SERVICE_TYPES = %w[git-upload-pack git-receive-pack]

    attr_reader :git

    def initialize(git:, auth:)
      @git = git
      @auth = auth
    end

    ##
    # Processes pack file exchange requests for both push and pull.  Ensures
    # that the request is allowed and properly formatted.
    #
    # @param [String] pack_type the type of pack exchange to perform per the
    #   request.
    #
    # @return a Rack response object.
    def call(env)
      encoding = env["HTTP_CONTENT_ENCODING"]
      request_body = env["rack.input"]
      pack_type = env["grack.matchdata"]["pack_type"]
      @auth.pack_type = pack_type
      content_type = env["CONTENT_TYPE"]

      unless content_type == "application/x-#{pack_type}-request" &&
          valid_pack_type?(pack_type) && @auth.authorized?
          return ErrorResponse.no_access
      end

      headers = { "Content-Type" => "application/x-#{pack_type}-result" }
      exchange_pack(headers, request_io_in(request_body, encoding), pack_type)
    end

    private

    ##
    # Opens a tunnel for the pack file exchange protocol between the client and
    # the Git adapter.
    #
    # @param [Hash] headers headers to provide in the Rack response.
    # @param [#read] io_in a readable, IO-like object providing client input
    #   data.
    # @param [Hash] opts options to pass to the Git adapter's #handle_pack
    #   method.
    #
    # @return a Rack response object.
    def exchange_pack(headers, io_in, pack_type, opts = {})
      Rack::Response.new([], 200, headers).finish do |response|
        git.handle_pack(pack_type, io_in, response, opts)
      end
    end

    ##
    # Determines whether or not the requested pack type is valid.
    #
    # @return [Boolean] +true+ if the pack type is valid; otherwise, +false+.
    def valid_pack_type?(pack_type)
      VALID_SERVICE_TYPES.include?(pack_type)
    end

    ##
    # Transparently ensures that the request body is not compressed.
    #
    # @return [#read] a +read+-able object that yields uncompressed data from
    #   the request body.
    def request_io_in(request_body, encoding)
      return request_body unless encoding =~ /gzip/
      Zlib::GzipReader.new(request_body)
    end
  end
end
