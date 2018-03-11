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
      @middleware =
        opts.fetch(:middleware, Noop)
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
      env["grack.root"] = @root
      env["grack.allow_push"] = @allow_push
      env["grack.allow_pull"] = @allow_pull
      env["grack.git"] = @git_adapter_factory.call
      middleware = @middleware

      app =
        Rack::Builder.new do
          use Route
          use middleware
          run DispatchHandler.new
        end

      app.call(env)
    end
  end
end
