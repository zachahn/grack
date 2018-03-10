##
# A namespace for all Grack functionality.
module Grack
  ##
  # A Rack application for serving Git repositories over HTTP.
  class App
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
      result = Route.new(git: git, root: root).call(env)
      auth = Auth.new(
        env: env,
        allow_push: @allow_push,
        allow_pull: @allow_pull,
        git: @git,
        request_verb: result[:verb]
      )

      handler = result[:handler].new(
        git: @git,
        auth: auth
      )

      match = result[:matches]

      case handler
      when HandleErrorBadRequest,
        HandleErrorNoAccess,
        HandleErrorNotFound,
        HandleErrorMethodNotAllowed
        return handler.call(env)
      when HandlePack
        env["grack.pack_type"] = match[2]
        return handler.call(env)
      when HandleInfoRefs
        return handler.call(env)
      when HandleTextFile,
        HandleInfoPacks,
        HandleLooseObject,
        HandlePackFile,
        HandleIdxFile
        env["grack.path"] = match[2]
        return handler.call(env)
      end
    end
  end
end
