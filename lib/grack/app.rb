##
# A namespace for all Grack functionality.
module Grack
  ##
  # A Rack application for serving Git repositories over HTTP.
  class App
    ##
    # A list of supported pack service types.
    VALID_SERVICE_TYPES = %w[git-upload-pack git-receive-pack]

    ##
    # Route mappings from URIs to valid verbs and handler functions.
    ROUTES = [
      [%r{/(.*?)/(git-(?:upload|receive)-pack)$}, "POST", :handle_pack],
      [%r{/(.*?)/info/refs$}, "GET", :info_refs],
      [%r{/(.*?)/(HEAD)$}, "GET", :text_file],
      [%r{/(.*?)/(objects/info/alternates)$}, "GET", :text_file],
      [%r{/(.*?)/(objects/info/http-alternates)$}, "GET", :text_file],
      [%r{/(.*?)/(objects/info/packs)$}, "GET", :info_packs],
      [%r{/(.*?)/(objects/info/[^/]+)$}, "GET", :text_file],
      [%r'/(.*?)/(objects/[0-9a-f]{2}/[0-9a-f]{38})$', "GET", :loose_object],
      [%r'/(.*?)/(objects/pack/pack-[0-9a-f]{40}\.pack)$', "GET", :pack_file],
      [%r'/(.*?)/(objects/pack/pack-[0-9a-f]{40}\.idx)$', "GET", :idx_file],
    ]

    ##
    # Creates a new instance of this application with the configuration provided
    # by _opts_.
    #
    # @param [Hash] opts a hash of supported options.
    # @option opts [String] :root (Dir.pwd) a directory path containing 1 or
    #   more Git repositories.
    # @option opts [Boolean, nil] :allow_push (nil) determines whether or not to
    #   allow pushes into the repositories.  +nil+ means to defer to the
    #   requested repository.
    # @option opts [Boolean, nil] :allow_pull (nil) determines whether or not to
    #   allow fetches/pulls from the repositories.  +nil+ means to defer to the
    #   requested repository.
    # @option opts [#call] :git_adapter_factory (->{ GitAdapter.new }) a
    #   call-able object that creates Git adapter instances per request.
    def initialize(opts = {})
      @root = Pathname.new(opts.fetch(:root, ".")).expand_path
      @allow_push = opts.fetch(:allow_push, nil)
      @allow_pull = opts.fetch(:allow_pull, nil)
      @git_adapter_factory =
        opts.fetch(:git_adapter_factory, -> { GitAdapter.new })
    end

    ##
    # The Rack handler entry point for this application.  This duplicates the
    # object and uses the duplicate to perform the work in order to enable
    # thread safe request handling.
    #
    # @param [Hash] env a Rack request hash.
    #
    # @return a Rack response object.
    def call(env)
      dup._call(env)
    end

    protected

    ##
    # The real request handler.
    #
    # @param [Hash] env a Rack request hash.
    #
    # @return a Rack response object.
    def _call(env)
      @git = @git_adapter_factory.call
      @env = env
      @request = Rack::Request.new(env)
      @auth = Auth.new(
        env: env,
        allow_push: @allow_push,
        allow_pull: @allow_pull,
        git: @git
      )
      route
    end

    private

    ##
    # The Rack request hash.
    attr_reader :env

    ##
    # The request object built from the request hash.
    attr_reader :request

    ##
    # The Git adapter instance for the requested repository.
    attr_reader :git

    ##
    # The path containing 1 or more Git repositories which may be requested.
    attr_reader :root

    ##
    # The path to the repository.
    attr_reader :repository_uri

    ##
    # The requested pack type.  Will be +nil+ for requests that do no involve
    # pack RPCs.
    attr_reader :pack_type

    ##
    # Routes requests to appropriate handlers.  Performs request path cleanup
    # and several sanity checks prior to attempting to handle the request.
    #
    # @return a Rack response object.
    def route
      # Sanitize the URI:
      # * Unescape escaped characters
      # * Replace runs of / with a single /
      path_info = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, "/")

      ROUTES.each do |path_matcher, verb, handler|
        path_info.match(path_matcher) do |match|
          @repository_uri = match[1]
          @auth.request_verb = verb

          return method_not_allowed unless verb == request.request_method
          return ErrorResponse.bad_request if bad_uri?(@repository_uri)

          git.repository_path = root + @repository_uri
          return ErrorResponse.not_found unless git.exist?

          if handler == :handle_pack
            pack_type = match[2]
            return handle_pack(pack_type)
          elsif handler == :info_refs
            return info_refs
          elsif handler == :text_file
            path = match[2]
            return text_file(path)
          elsif handler == :info_packs
            path = match[2]
            return info_packs(path)
          elsif handler == :loose_object
            path = match[2]
            return loose_object(path)
          elsif handler == :pack_file
            path = match[2]
            return pack_file(path)
          elsif handler == :idx_file
            path = match[2]
            return idx_file(path)
          end
        end
      end
      ErrorResponse.not_found
    end

    ##
    # Processes pack file exchange requests for both push and pull.  Ensures
    # that the request is allowed and properly formatted.
    #
    # @param [String] pack_type the type of pack exchange to perform per the
    #   request.
    #
    # @return a Rack response object.
    def handle_pack(pack_type)
      @pack_type = pack_type
      @auth.pack_type = pack_type
      unless request.content_type == "application/x-#{@pack_type}-request" &&
             valid_pack_type? && @auth.authorized?
        return ErrorResponse.no_access
      end

      headers = { "Content-Type" => "application/x-#{@pack_type}-result" }
      exchange_pack(headers, request_io_in)
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
    def info_refs
      @pack_type = request.params["service"]
      @auth.pack_type = @pack_type
      return ErrorResponse.no_access unless @auth.authorized?

      if @pack_type.nil?
        git.update_server_info
        send_file(
          git.file("info/refs"), "text/plain; charset=utf-8", hdr_nocache
        )
      elsif valid_pack_type?
        headers = hdr_nocache
        headers["Content-Type"] = "application/x-#{@pack_type}-advertisement"
        exchange_pack(headers, nil, { advertise_refs: true })
      else
        ErrorResponse.not_found
      end
    end

    ##
    # Processes requests for info packs for the requested repository.
    #
    # @param [String] path the path to an info pack file within a Git
    #   repository.
    #
    # @return a Rack response object.
    def info_packs(path)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(git.file(path), "text/plain; charset=utf-8", hdr_nocache)
    end

    ##
    # Processes a request for a loose object at _path_ for the selected
    # repository.  If the file is located, the content type is set to
    # +application/x-git-loose-object+ and permanent caching is enabled.
    #
    # @param [String] path the path to a loose object file within a Git
    #   repository, such as +objects/31/d73eb4914a8ddb6cb0e4adf250777161118f90+.
    #
    # @return a Rack response object.
    def loose_object(path)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(
        git.file(path), "application/x-git-loose-object", hdr_cache_forever
      )
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
    def pack_file(path)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(
        git.file(path), "application/x-git-packed-objects", hdr_cache_forever
      )
    end

    ##
    # Process a request for a pack index file located at _path_ for the selected
    # repository.  If the file is located, the content type is set to
    # +application/x-git-packed-objects-toc+ and permanent caching is enabled.
    #
    # @param [String] path the path to a pack index file within a Git
    #   repository, such as
    #   +pack/pack-62c9f443d8405cd6da92dcbb4f849cc01a339c06.idx+.
    #
    # @return a Rack response object.
    def idx_file(path)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(
        git.file(path),
        "application/x-git-packed-objects-toc",
        hdr_cache_forever
      )
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
    def text_file(path)
      return ErrorResponse.no_access unless @auth.authorized?
      send_file(git.file(path), "text/plain", hdr_nocache)
    end

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
    def exchange_pack(headers, io_in, opts = {})
      Rack::Response.new([], 200, headers).finish do |response|
        git.handle_pack(pack_type, io_in, response, opts)
      end
    end

    ##
    # Transparently ensures that the request body is not compressed.
    #
    # @return [#read] a +read+-able object that yields uncompressed data from
    #   the request body.
    def request_io_in
      return request.body unless env["HTTP_CONTENT_ENCODING"] =~ /gzip/
      Zlib::GzipReader.new(request.body)
    end

    ##
    # Determines whether or not the requested pack type is valid.
    #
    # @return [Boolean] +true+ if the pack type is valid; otherwise, +false+.
    def valid_pack_type?
      VALID_SERVICE_TYPES.include?(pack_type)
    end

    ##
    # Determines whether or not _path_ is an acceptable URI.
    #
    # @param [String] path the path part of the request URI.
    #
    # @return [Boolean] +true+ if the requested path is considered invalid;
    #   otherwise, +false+.
    def bad_uri?(path)
      invalid_segments = %w[. ..]
      path.split("/").any? { |segment| invalid_segments.include?(segment) }
    end

    # --------------------------------------
    # HTTP error response handling functions
    # --------------------------------------

    ##
    # A shorthand for specifying a text content type for the Rack response.
    PLAIN_TYPE = { "Content-Type" => "text/plain" }

    ##
    # Returns a Rack response appropriate for requests that use invalid verbs
    # for the requested resources.
    #
    # For HTTP 1.1 requests, a 405 code is returned.  For other versions, the
    # value from #bad_request is returned.
    #
    # @return a Rack response appropriate for requests that use invalid verbs
    #   for the requested resources.
    def method_not_allowed
      if env["SERVER_PROTOCOL"] == "HTTP/1.1"
        [405, PLAIN_TYPE, ["Method Not Allowed"]]
      else
        ErrorResponse.bad_request
      end
    end

    # ------------------------
    # header writing functions
    # ------------------------

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
