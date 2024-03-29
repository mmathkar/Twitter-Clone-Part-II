defmodule ChatroomWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chatroom

  socket "/socket", ChatroomWeb.UserSocket

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/", from: :chatroom, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_chatroom_key",
    signing_salt: "7a90DqJg"

  plug ChatroomWeb.Router

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    :ets.new(:users, [:set, :public, :named_table])
    :ets.new(:hashtagMap, [:set, :public, :named_table])
    :ets.new(:mentionsMap, [:set, :public, :named_table])
    :ets.new(:followersTable, [:set, :public, :named_table])
    :ets.new(:followsTable, [:set, :public, :named_table])
    :ets.new(:tweetsDB, [:set, :public, :named_table])
    :ets.new(:userToIPMap, [:set, :public, :named_table])
    :ets.new(:map_of_sockets, [:set, :public, :named_table])
    


    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
