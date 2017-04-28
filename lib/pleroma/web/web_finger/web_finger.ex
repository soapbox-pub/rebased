defmodule Pleroma.Web.WebFinger do
  alias Pleroma.XmlBuilder
  alias Pleroma.User
  alias Pleroma.Web.OStatus

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
    regex = ~r/acct:(?<username>\w+)@#{host}/
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
        {:Link, %{rel: "http://schemas.google.com/g/2010#updates-from", type: "application/atom+xml", href: OStatus.feed_path(user)}}
      ]
    }
    |> XmlBuilder.to_doc
  end
end
