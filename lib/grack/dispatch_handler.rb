module Grack
  class DispatchHandler
    ##
    # Routes requests to appropriate handlers.  Performs request path cleanup
    # and several sanity checks prior to attempting to handle the request.
    #
    # @return a Rack response object.
    def call(env)
      git = env["grack.git"]
      root = env["grack.root"]
      auth = Auth.new(
        env: env,
        allow_push: env["grack.allow_push"],
        allow_pull: env["grack.allow_pull"],
        git: git,
        request_verb: env["REQUEST_METHOD"]
      )
      handler = env["grack.request_handler"].new(
        git: git,
        auth: auth
      )
      match = env["grack.matchdata"]

      return handler.call(env)
    end
  end
end
