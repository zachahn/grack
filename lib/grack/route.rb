module Grack
  class Route
    ##
    # Route mappings from URIs to valid verbs and handler functions.
    ROUTES = [
      [%r{/(?<repository_name>.*?)/(?<pack_type>git-(?:upload|receive)-pack)$}, "POST", HandlePack],
      [%r{/(?<repository_name>.*?)/info/refs$}, "GET", HandleInfoRefs],
      [%r{/(?<repository_name>.*?)/(?<path>HEAD)$}, "GET", HandleTextFile],
      [%r{/(?<repository_name>.*?)/(?<path>objects/info/alternates)$}, "GET", HandleTextFile],
      [%r{/(?<repository_name>.*?)/(?<path>objects/info/http-alternates)$}, "GET", HandleTextFile],
      [%r{/(?<repository_name>.*?)/(?<path>objects/info/packs)$}, "GET", HandleInfoPacks],
      [%r{/(?<repository_name>.*?)/(?<path>objects/info/[^/]+)$}, "GET", HandleTextFile],
      [%r'/(?<repository_name>.*?)/(?<path>objects/[0-9a-f]{2}/[0-9a-f]{38})$', "GET", HandleLooseObject],
      [%r'/(?<repository_name>.*?)/(?<path>objects/pack/pack-[0-9a-f]{40}\.pack)$', "GET", HandlePackFile],
      [%r'/(?<repository_name>.*?)/(?<path>objects/pack/pack-[0-9a-f]{40}\.idx)$', "GET", HandleIdxFile],
    ]

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      git = env["grack.git"]
      root = env["grack.root"]

      # Sanitize the URI:
      # * Unescape escaped characters
      # * Replace runs of / with a single /
      path_info = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, "/")

      ROUTES.each do |path_matcher, verb, handler_class|
        path_info.match(path_matcher) do |match|
          git.repository_path = root + match["repository_name"]
          env["grack.matchdata"] = match

          env["grack.request_handler"] =
            if verb != request.request_method
              HandleErrorMethodNotAllowed
            elsif bad_uri?(match[1])
              HandleErrorBadRequest
            elsif !git.exist?
              HandleErrorNotFound
            else
              handler_class
            end
        end
      end

      if !env.key?("grack.request_handler")
        env["grack.request_handler"] = HandleErrorNotFound
      end

      @app.call(env)
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
