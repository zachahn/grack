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
