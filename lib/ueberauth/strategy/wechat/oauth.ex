defmodule Ueberauth.Strategy.Wechat.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Wechat.

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.Wechat.OAuth,
        client_id: System.get_env("WECHAT_CLIENT_ID"),
        client_secret: System.get_env("WECHAT_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://api.weixin.qq.com/sns",
    authorize_url: "https://open.weixin.qq.com/connect/oauth2/authorize",
    token_url: "/oauth2/access_token",
    token_method: "get"
  ]

  @doc """
  Construct a client for requests to Wechat.

  Optionally include any OAuth2 options here to be merged with the defaults.

      Ueberauth.Strategy.Wechat.OAuth.client(redirect_uri: "http://localhost:4000/auth/wechat/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.Wechat`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    opts =
      Keyword.merge(@defaults, Application.get_env(:ueberauth, Ueberauth.Strategy.Wechat.OAuth))
      |> Keyword.merge(opts)

    OAuth2.Client.new(opts)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    client(opts)
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    client(token: token)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    client_options = Keyword.get(options, :client_options, [])
    client = OAuth2.Client.get_token!(client(client_options), params, headers, options)

    token =
      client.token.access_token
      |> Poison.decode!()
      |> OAuth2.AccessToken.new()

    Map.merge(
      token,
      Enum.into(token.other_params, %{other_params: %{}}, fn {k, v} -> {String.to_atom(k), v} end)
    )
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    client
    |> put_param(:response_type, "code")
    |> put_param(:appid, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
  end

  def get_token(client, params, headers) do
    {code, params} = Keyword.pop(params, :code, client.params["code"])

    unless code do
      raise OAuth2.Error, reason: "Missing required key `code` for `#{inspect(__MODULE__)}`"
    end

    client
    |> put_header("Accept", "application/json")
    |> put_param(:code, code)
    |> put_param(:grant_type, "authorization_code")
    |> put_param(:appid, client.client_id)
    |> put_param(:secret, client.client_secret)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
    |> put_headers(headers)
  end
end
