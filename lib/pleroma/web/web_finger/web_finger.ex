defmodule Pleroma.Web.WebFinger do
  alias Pleroma.XmlBuilder
  alias Pleroma.User
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.XML
  require Logger

  def host_meta() do
    base_url  = Pleroma.Web.base_url
    {
      :XRD, %{ xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0" },
      {
        :Link, %{ rel: "lrdd", type: "application/xrd+xml", template: "#{base_url}/.well-known/webfinger?resource={uri}"  }
      }
    }
    |> XmlBuilder.to_doc
  end

  def webfinger(resource) do
    host = Pleroma.Web.host
    regex = ~r/(acct:)?(?<username>\w+)@#{host}/
    case Regex.named_captures(regex, resource) do
      %{"username" => username} ->
        user = User.get_cached_by_nickname(username)
        {:ok, represent_user(user)}
      _ -> nil
    end
  end

  def represent_user(user) do
    {
      :XRD, %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{Pleroma.Web.host}"},
        {:Alias, user.ap_id},
        {:Link, %{rel: "http://schemas.google.com/g/2010#updates-from", type: "application/atom+xml", href: OStatus.feed_path(user)}},
        {:Link, %{rel: "salmon", href: OStatus.salmon_path(user)}}
      ]
    }
    |> XmlBuilder.to_doc
  end

  # FIXME: Make this call the host-meta to find the actual address.
  defp webfinger_address(domain) do
    "//#{domain}/.well-known/webfinger"
  end

  defp webfinger_from_xml(doc) do
    magic_key = XML.string_from_xpath(~s{//Link[@rel="magic-public-key"]/@href}, doc)
    "data:application/magic-public-key," <> magic_key = magic_key
    topic = XML.string_from_xpath(~s{//Link[@rel="http://schemas.google.com/g/2010#updates-from"]/@href}, doc)
    subject = XML.string_from_xpath("//Subject", doc)
    salmon = XML.string_from_xpath(~s{//Link[@rel="salmon"]/@href}, doc)
    data = %{
      magic_key: magic_key,
      topic: topic,
      subject: subject,
      salmon: salmon
    }
    {:ok, data}
  end

  def finger(account, getter \\ &HTTPoison.get/3) do
    domain = with [_name, domain] <- String.split(account, "@") do
               domain
             else _e ->
               URI.parse(account).host
             end
    address = webfinger_address(domain)

    # try https first
    response = with {:ok, result} <- getter.("https:" <> address, ["Accept": "application/xrd+xml"], [params: [resource: account]]) do
                 {:ok, result}
               else _ ->
                 getter.("http:" <> address, ["Accept": "application/xrd+xml"], [params: [resource: account]])
               end

    with {:ok, %{status_code: status_code, body: body}} when status_code in 200..299 <- response,
         doc <- XML.parse_document(body),
         {:ok, data} <- webfinger_from_xml(doc) do
      {:ok, data}
    else
      e ->
        Logger.debug("Couldn't finger #{account}.")
        Logger.debug(inspect(e))
        {:error, e}
    end
  end
end
