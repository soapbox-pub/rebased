defmodule HttpRequestMock do
  def request(
        %Tesla.Env{
          url: url,
          method: method,
          headers: headers,
          query: query,
          body: body
        } = _env
      ) do
    with {:ok, res} <- apply(__MODULE__, method, [url, query, body, headers]) do
      res
    else
      {_, r} = error ->
        IO.warn(r)
        error
    end
  end

  # GET Requests
  #
  def get(url, query \\ [], body \\ [], headers \\ [])

  def get("https://social.heldscal.la/api/statuses/user_timeline/23211.atom", _, _, _) do
    {:ok, %Tesla.Env{
        status: 200,
        body: File.read!(
          "test/fixtures/httpoison_mock/https___social.heldscal.la_api_statuses_user_timeline_23211.atom.xml"
        )}}
  end

  def get("https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/23211", _, _, _) do
    {:ok, %Tesla.Env{
        status: 200,
        body: File.read!("test/fixtures/httpoison_mock/https___social.heldscal.la_user_23211.xml")}}
  end

  def get("http://social.heldscal.la/.well-known/host-meta", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/httpoison_mock/social.heldscal.la_host_meta")}}
  end

  def get("https://social.heldscal.la/.well-known/host-meta", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/httpoison_mock/social.heldscal.la_host_meta")}}
  end

  def get("https://mastodon.social/users/lambadalambda.atom", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/lambadalambda.atom")}}
  end

  def get("https://social.heldscal.la/user/23211", _, _, [Accept: "application/activity+json"]) do
    {:ok,
     Tesla.Mock.json(%{"id" => "https://social.heldscal.la/user/23211"}, status: 200)
    }
  end

  def get(url, query, body, headers) do
    {:error,
     "Not implemented the mock response for get #{inspect(url)}, #{query}, #{inspect(body)}, #{
     inspect(headers)
     }"}
  end


  # POST Requests
  #

  def post(url, query \\ [], body \\ [], headers \\ [])

  def post("http://example.org/needs_refresh", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post(url, _query, _body, _headers) do
    {:error, "Not implemented the mock response for post #{inspect(url)}"}
  end
end
