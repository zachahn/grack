module Grack
  class HandleTextFile
    attr_reader :git

    def initialize(git:, auth:)
      @git = git
      @auth = auth
    end

    ##
    # Process a request for a generic file located at _path_ for the selected
    # repository.  If the file is located, the content type is set to
    # +text/plain+ and caching is disabled.
    #
    # @param [String] path the path to a file within a Git repository, such as
    #   +HEAD+.
    #
    # @return a Rack response object.
    def call(path:)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(git.file(path), "text/plain", hdr_nocache)
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
