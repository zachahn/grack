##
# A namespace for all Grack functionality.
module Grack
  ##
  # A Rack application for serving Git repositories over HTTP.
  class App
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
          auth = Auth.new(
            env: env,
            allow_push: @allow_push,
            allow_pull: @allow_pull,
            git: @git,
            request_verb: verb
          )

          return method_not_allowed unless verb == request.request_method
          return ErrorResponse.bad_request if bad_uri?(@repository_uri)

          git.repository_path = root + @repository_uri
          return ErrorResponse.not_found unless git.exist?

          if handler == :handle_pack
            return HandlePack.new(
              git: git,
              auth: auth
            ).call(
              pack_type: match[2],
              content_type: request.content_type,
              request_body: request.body,
              encoding: env["HTTP_CONTENT_ENCODING"]
            )
          elsif handler == :info_refs
            return HandleInfoRefs.new(
              git: git,
              auth: auth
            ).call(pack_type: request.params["service"])
          elsif handler == :text_file
            return HandleTextFile.new(
              git: git,
              auth: auth
            ).call(path: match[2])
          elsif handler == :info_packs
            return HandleInfoPacks.new(
              git: git,
              auth: auth
            ).call(path: match[2])
          elsif handler == :loose_object
            return HandleLooseObject.new(
              git: git,
              auth: auth
            ).call(path: match[2])
          elsif handler == :pack_file
            return HandlePackFile.new(
              git: git,
              auth: auth
            ).call(path: match[2])
          elsif handler == :idx_file
            return HandleIdxFile.new(
              git: git,
              auth: auth
            ).call(path: match[2])
          end
        end
      end
      ErrorResponse.not_found
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
  end
end
