module Grack
  class Auth
    def initialize(env:, git:, allow_push:, allow_pull:, request_verb:)
      @env = env
      @git = git
      @allow_push = allow_push
      @allow_pull = allow_pull
      @request_verb = request_verb
    end

    ##
    # The HTTP verb of the request.
    attr_reader :request_verb

    ##
    # The requested pack type.  Will be +nil+ for requests that do no involve
    # pack RPCs.
    attr_accessor :pack_type

    ##
    # @return [Boolean] +true+ if the request is authorized; otherwise, +false+.
    def authorized?
      return allow_pull? if need_read?
      allow_push?
    end

    ##
    # @return [Boolean] +true+ if read permissions are needed; otherwise,
    #   +false+.
    def need_read?
      (request_verb == "GET" && pack_type != "git-receive-pack") ||
        request_verb == "POST" && pack_type == "git-upload-pack"
    end

    ##
    # Determines whether or not pushes into the requested repository are
    # allowed.
    #
    # @return [Boolean] +true+ if pushes are allowed, +false+ otherwise.
    def allow_push?
      @allow_push || (@allow_push.nil? && @git.allow_push?)
    end

    ##
    # Determines whether or not fetches/pulls from the requested repository are
    # allowed.
    #
    # @return [Boolean] +true+ if fetches are allowed, +false+ otherwise.
    def allow_pull?
      @allow_pull || (@allow_pull.nil? && @git.allow_pull?)
    end
  end
end
