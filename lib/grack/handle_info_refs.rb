module Grack
  class HandleInfoRefs
    ##
    # A list of supported pack service types.
    VALID_SERVICE_TYPES = %w[git-upload-pack git-receive-pack]

    attr_reader :git

    def initialize(git:, auth:, request_verb:)
      @git = git
      @auth = auth
    end

    ##
    # Processes requests for the list of refs for the requested repository.
    #
    # This works for both Smart HTTP clients and basic ones.  For basic clients,
    # the Git adapter is used to update the +info/refs+ file which is then
    # served to the clients.  For Smart HTTP clients, the more efficient pack
    # file exchange mechanism is used.
    #
    # @return a Rack response object.
    def call(pack_type:)
      @auth.pack_type = pack_type
      return ErrorResponse.no_access unless @auth.authorized?

      if pack_type.nil?
        git.update_server_info
        send_file(
          git.file("info/refs"), "text/plain; charset=utf-8", hdr_nocache
        )
      elsif valid_pack_type?(pack_type)
        headers = hdr_nocache
        headers["Content-Type"] = "application/x-#{pack_type}-advertisement"
        exchange_pack(headers, nil, pack_type, { advertise_refs: true })
      else
        ErrorResponse.not_found
      end
    end

    private

    ##
    # Produces a Rack response that wraps the output from the Git adapter.
    #
    # A 404 response is produced if _streamer_ is +nil+.  Otherwise a 200
    # response is produced with _streamer_ as the response body.
    #
    # @param [FileStreamer,IOStreamer] streamer a provider of content for the
    #   response body.
    # @param [String] content_type the MIME type of the content.
    # @param [Hash] headers additional headers to include in the response.
    #
    # @return a Rack response object.
    def send_file(streamer, content_type, headers = {})
      return ErrorResponse.not_found if streamer.nil?

      headers["Content-Type"] = content_type
      headers["Last-Modified"] = streamer.mtime.httpdate

      [200, headers, streamer]
    end

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
    # NOTE: This should probably be converted to a constant.
    #
    # @return a hash of headers that should prevent caching of a Rack response.
    def hdr_nocache
      {
        "Expires"       => "Fri, 01 Jan 1980 00:00:00 GMT",
        "Pragma"        => "no-cache",
        "Cache-Control" => "no-cache, max-age=0, must-revalidate",
      }
    end
  end
end
