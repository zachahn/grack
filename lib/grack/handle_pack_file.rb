module Grack
  class HandlePackFile
    attr_reader :git

    def initialize(git:, auth:)
      @git = git
      @auth = auth
    end

    ##
    # Process a request for a pack file located at _path_ for the selected
    # repository.  If the file is located, the content type is set to
    # +application/x-git-packed-objects+ and permanent caching is enabled.
    #
    # @param [String] path the path to a pack file within a Git repository such
    #   as +pack/pack-62c9f443d8405cd6da92dcbb4f849cc01a339c06.pack+.
    #
    # @return a Rack response object.
    def call(env)
      path = env["grack.matchdata"]["path"]
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(
        git.file(path), "application/x-git-packed-objects", hdr_cache_forever
      )
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
    # @return a hash of headers that should trigger caches permanent caching.
    def hdr_cache_forever
      now = Time.now().to_i
      {
        "Date"          => now.to_s,
        "Expires"       => (now + 31_536_000).to_s,
        "Cache-Control" => "public, max-age=31536000",
      }
    end
  end
end
