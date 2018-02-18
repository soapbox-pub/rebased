defmodule Pleroma.Web.WebFinger do
  @httpoison Application.get_env(:pleroma, :httpoison)

  alias Pleroma.{Repo, User, XmlBuilder}
  alias Pleroma.Web
  alias Pleroma.Web.{XML, Salmon, OStatus}
  require Logger

  def host_meta do
    base_url  = Web.base_url
    {
      :XRD, %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      {
        :Link, %{rel: "lrdd", type: "application/xrd+xml", template: "#{base_url}/.well-known/webfinger?resource={uri}"}
      }
    }
    |> XmlBuilder.to_doc
  end

  def webfinger(resource) do
    host = Pleroma.Web.Endpoint.host
    regex = ~r/(acct:)?(?<username>\w+)@#{host}/
    with %{"username" => username} <- Regex.named_captures(regex, resource) do
      user = User.get_by_nickname(username)
      {:ok, represent_user(user)}
    else _e ->
      with user when not is_nil(user) <- User.get_cached_by_ap_id(resource) do
        {:ok, represent_user(user)}
      else _e ->
        {:error, "Couldn't find user"}
      end
    end
  end

  def represent_user(user) do
    {:ok, user} = ensure_keys_present(user)
    {:ok, _private, public} = Salmon.keys_from_pem(user.info["keys"])
    magic_key = Salmon.encode_key(public)
    {
      :XRD, %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{Pleroma.Web.Endpoint.host}"},
        {:Alias, user.ap_id},
        {:Link, %{rel: "http://schemas.google.com/g/2010#updates-from", type: "application/atom+xml", href: OStatus.feed_path(user)}},
        {:Link, %{rel: "http://webfinger.net/rel/profile-page", type: "text/html", href: user.ap_id}},
        {:Link, %{rel: "salmon", href: OStatus.salmon_path(user)}},
        {:Link, %{rel: "magic-public-key", href: "data:application/magic-public-key,#{magic_key}"}},
        {:Link, %{rel: "self", type: "application/activity+json", href: user.ap_id}},
        {:Link, %{rel: "http://ostatus.org/schema/1.0/subscribe", template: OStatus.remote_follow_path()}}
      ]
    }
    |> XmlBuilder.to_doc
  end

  # This seems a better fit in Salmon
  def ensure_keys_present(user) do
    info = user.info || %{}
    if info["keys"] do
      {:ok, user}
    else
      {:ok, pem} = Salmon.generate_rsa_pem
      info = Map.put(info, "keys", pem)
      Repo.update(Ecto.Changeset.change(user, info: info))
    end
  end

  defp webfinger_from_xml(doc) do
    magic_key = XML.string_from_xpath(~s{//Link[@rel="magic-public-key"]/@href}, doc)
    "data:application/magic-public-key," <> magic_key = magic_key
    topic = XML.string_from_xpath(~s{//Link[@rel="http://schemas.google.com/g/2010#updates-from"]/@href}, doc)
    subject = XML.string_from_xpath("//Subject", doc)
    salmon = XML.string_from_xpath(~s{//Link[@rel="salmon"]/@href}, doc)
    subscribe_address = XML.string_from_xpath(~s{//Link[@rel="http://ostatus.org/schema/1.0/subscribe"]/@template}, doc)
    ap_id = XML.string_from_xpath(~s{//Link[@rel="self" and @type="application/activity+json"]/@href}, doc)
    data = %{
      "magic_key" => magic_key,
      "topic" => topic,
      "subject" => subject,
      "salmon" => salmon,
      "subscribe_address" => subscribe_address,
      "ap_id" => ap_id
    }
    {:ok, data}
  end

  def get_template_from_xml(body) do
    xpath = "//Link[@rel='lrdd' and @type='application/xrd+xml']/@template"
    with doc when doc != :error <- XML.parse_document(body),
      template when template != nil <- XML.string_from_xpath(xpath, doc) do
      {:ok, template}
    end
  end

  def find_lrdd_template(domain) do
    with {:ok, %{status_code: status_code, body: body}} when status_code in 200..299 <- @httpoison.get("http://#{domain}/.well-known/host-meta", [], follow_redirect: true) do
      get_template_from_xml(body)
    else
      _ ->
        with {:ok, %{body: body}} <- @httpoison.get("https://#{domain}/.well-known/host-meta", []) do
          get_template_from_xml(body)
        else
          e -> {:error, "Can't find lrdd template: #{inspect(e)}"}
        end
    end
  end

  def finger(account) do
    domain = with [_name, domain] <- String.split(account, "@") do
               domain
             else _e ->
               URI.parse(account).host
             end

    with {:ok, template} <- find_lrdd_template(domain),
         address <- String.replace(template, "{uri}", URI.encode(account)),
         response <- @httpoison.get(address, ["Accept": "application/xrd+xml"]),
         {:ok, %{status_code: status_code, body: body}} when status_code in 200..299 <- response,
         doc when doc != :error<- XML.parse_document(body),
         {:ok, data} <- webfinger_from_xml(doc) do
      {:ok, data}
    else
      e ->
        Logger.debug(fn -> "Couldn't finger #{account}." end)
        Logger.debug(fn -> inspect(e) end)
        {:error, e}
    end
  end
end
