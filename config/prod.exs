import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :crypto_app, CryptoAppWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :crypto_app, CryptoAppWeb.Endpoint,
  url: [host: "ocean-r3bm.onrender.com/", port: 443, scheme: "https"],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  render_errors: [view: CryptoAppWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: CryptoApp.PubSub,
  live_view: [signing_salt: "some_salt"],
  check_origin: ["https://ocean-r3bm.onrender.com"] 

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: CryptoApp.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
