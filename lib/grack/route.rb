module Grack
  class Route
    ##
    # Route mappings from URIs to valid verbs and handler functions.
    ROUTES = [
      [%r{/(.*?)/(git-(?:upload|receive)-pack)$}, "POST", HandlePack],
      [%r{/(.*?)/info/refs$}, "GET", HandleInfoRefs],
      [%r{/(.*?)/(HEAD)$}, "GET", HandleTextFile],
      [%r{/(.*?)/(objects/info/alternates)$}, "GET", HandleTextFile],
      [%r{/(.*?)/(objects/info/http-alternates)$}, "GET", HandleTextFile],
      [%r{/(.*?)/(objects/info/packs)$}, "GET", HandleInfoPacks],
      [%r{/(.*?)/(objects/info/[^/]+)$}, "GET", HandleTextFile],
      [%r'/(.*?)/(objects/[0-9a-f]{2}/[0-9a-f]{38})$', "GET", HandleLooseObject],
      [%r'/(.*?)/(objects/pack/pack-[0-9a-f]{40}\.pack)$', "GET", HandlePackFile],
      [%r'/(.*?)/(objects/pack/pack-[0-9a-f]{40}\.idx)$', "GET", HandleIdxFile],
    ]

    def initialize(git:, root:)
      @git = git
      @root = root
    end

    def call(env)
      request = Rack::Request.new(env)
      result = {}

      # Sanitize the URI:
      # * Unescape escaped characters
      # * Replace runs of / with a single /
      path_info = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, "/")

      ROUTES.each do |path_matcher, verb, handler_class|
        path_info.match(path_matcher) do |match|
          @git.repository_path = @root + match[1]
          result[:repository_uri] = match[1]
          result[:matches] = match
          result[:verb] = verb

          if verb != request.request_method
            result[:handler] = HandleErrorMethodNotAllowed
          elsif bad_uri?(result[:repository_uri])
            result[:handler] = HandleErrorBadRequest
          elsif !@git.exist?
            result[:handler] = HandleErrorNotFound
          else
            result[:handler] = handler_class
          end
        end
      end

      if !result.key?(:handler)
        result[:handler] = HandleErrorNotFound
      end

      result
    end

    private

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
  end
end
