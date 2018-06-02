require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class ChoerodonOAuth2Generic < OmniAuth::Strategies::OAuth2
      option :name, 'choerodon_oauth2_generic'

      option :client_options, { # Defaults are set for GitLab example implementation
        site: 'https://gitlab.com', # The URL for your OAuth 2 server
        user_info_url: '/api/v3/user', # The endpoint on your OAuth 2 server that provides user info for the current user
        authorize_url: '/oauth/authorize', # The authorization endpoint for your OAuth server
        token_url: '/oauth/token' # The token request endpoint for your OAuth server
      }

      option :user_response_structure, { # info about the structure of the response from the oauth server's user_info_url (specified above)
        root_path: [], # The default path to the user attributes (i.e. ['data', 'attributes'])
        id_path: 'id', # The name or path to the user ID (i.e. ['data', 'id]').  Scalars are considered relative to `root_path`, Arrays are absolute paths.
        attributes: { # Alternate paths or names for any attributes that don't match the default
          name: 'name', # Scalars are treated as relative (i.e. 'username' would point to response['data']['attributes']['username'], given a root_path of ['data', 'attributes'])
          email: 'email', # Arrays are treated as absolute paths (i.e. ['included', 'contacts', 0, 'email'] would point to response['included']['contacts'][0]['email'], regardless of root_path)
          nickname: 'nickname',
          first_name: 'first_name',
          last_name: 'last_name',
          location: 'location',
          description: 'description',
          image: 'image',
          phone: 'phone',
          urls: 'urls'
        }
      }

      option :redirect_url

      uid do
        fetch_user_info(user_paths[:id_path]).to_s
      end

      info do
        user_paths[:attributes].inject({}) do |user_hash, (field, path)|
          value = fetch_user_info(path)
          user_hash[field] = value if value
          user_hash
        end
      end

      extra do
        { raw_info: raw_info }
      end

      def raw_info
        @raw_info ||= access_token.get(options.client_options[:user_info_url]).parsed
      end

      def authorize_params
        params = super
        Hash[params.map { |k, v| [k, v.respond_to?(:call) ? v.call(request) : v] }]
      end

      def build_access_token
        options.token_params.merge!(:headers => {'Authorization' => basic_auth_header })
        super
      end

      def basic_auth_header
        "Basic " + Base64.strict_encode64("#{options[:client_id]}:#{options[:client_secret]}")
      end  

      private

      def user_paths
        options.user_response_structure
      end

      def fetch_user_info(path)
        return nil unless path
        full_path = path.is_a?(Array) ? path : Array(user_paths[:root_path]) + [path]
        full_path.inject(raw_info) { |info, key| info[key] rescue nil }
      end

      def callback_url
        options.redirect_url || (full_host + script_name + callback_path)
      end
    end
  end
end

OmniAuth.config.add_camelization 'choerodon_oauth2_generic', 'ChoerodonOAuth2Generic'