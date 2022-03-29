# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger do
  alias Pleroma.HTTP
  alias Pleroma.User
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.Web.XML
  alias Pleroma.XmlBuilder
  require Jason
  require Logger

  def host_meta do
    base_url = Endpoint.url()

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      {
        :Link,
        %{
          rel: "lrdd",
          type: "application/xrd+xml",
          template: "#{base_url}/.well-known/webfinger?resource={uri}"
        }
      }
    }
    |> XmlBuilder.to_doc()
  end

  def webfinger(resource, fmt) when fmt in ["XML", "JSON"] do
    host = Pleroma.Web.Endpoint.host()
    regex = ~r/(acct:)?(?<username>[a-z0-9A-Z_\.-]+)@#{host}/

    with %{"username" => username} <- Regex.named_captures(regex, resource),
         %User{} = user <- User.get_cached_by_nickname(username) do
      {:ok, represent_user(user, fmt)}
    else
      _e ->
        with %User{} = user <- User.get_cached_by_ap_id(resource) do
          {:ok, represent_user(user, fmt)}
        else
          _e ->
            {:error, "Couldn't find user"}
        end
    end
  end

  defp gather_links(%User{} = user) do
    [
      %{
        "rel" => "http://webfinger.net/rel/profile-page",
        "type" => "text/html",
        "href" => user.ap_id
      }
    ] ++ Publisher.gather_webfinger_links(user)
  end

  defp gather_aliases(%User{} = user) do
    [user.ap_id | user.also_known_as]
  end

  def represent_user(user, "JSON") do
    {:ok, user} = User.ensure_keys_present(user)

    %{
      "subject" => "acct:#{user.nickname}@#{Pleroma.Web.Endpoint.host()}",
      "aliases" => gather_aliases(user),
      "links" => gather_links(user)
    }
  end

  def represent_user(user, "XML") do
    {:ok, user} = User.ensure_keys_present(user)

    aliases =
      user
      |> gather_aliases()
      |> Enum.map(&{:Alias, &1})

    links =
      gather_links(user)
      |> Enum.map(fn link -> {:Link, link} end)

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{Pleroma.Web.Endpoint.host()}"}
      ] ++ aliases ++ links
    }
    |> XmlBuilder.to_doc()
  end

  defp webfinger_from_xml(body) do
    with {:ok, doc} <- XML.parse_document(body) do
      subject = XML.string_from_xpath("//Subject", doc)

      subscribe_address =
        ~s{//Link[@rel="http://ostatus.org/schema/1.0/subscribe"]/@template}
        |> XML.string_from_xpath(doc)

      ap_id =
        ~s{//Link[@rel="self" and @type="application/activity+json"]/@href}
        |> XML.string_from_xpath(doc)

      data = %{
        "subject" => subject,
        "subscribe_address" => subscribe_address,
        "ap_id" => ap_id
      }

      {:ok, data}
    end
  end

  defp webfinger_from_json(body) do
    with {:ok, doc} <- Jason.decode(body) do
      data =
        Enum.reduce(doc["links"], %{"subject" => doc["subject"]}, fn link, data ->
          case {link["type"], link["rel"]} do
            {"application/activity+json", "self"} ->
              Map.put(data, "ap_id", link["href"])

            {"application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"", "self"} ->
              Map.put(data, "ap_id", link["href"])

            {nil, "http://ostatus.org/schema/1.0/subscribe"} ->
              Map.put(data, "subscribe_address", link["template"])

            _ ->
              Logger.debug("Unhandled type: #{inspect(link["type"])}")
              data
          end
        end)

      {:ok, data}
    end
  end

  def get_template_from_xml(body) do
    xpath = "//Link[@rel='lrdd']/@template"

    with {:ok, doc} <- XML.parse_document(body),
         template when template != nil <- XML.string_from_xpath(xpath, doc) do
      {:ok, template}
    end
  end

  def find_lrdd_template(domain) do
    with {:ok, %{status: status, body: body}} when status in 200..299 <-
           HTTP.get("http://#{domain}/.well-known/host-meta") do
      get_template_from_xml(body)
    else
      _ ->
        with {:ok, %{body: body, status: status}} when status in 200..299 <-
               HTTP.get("https://#{domain}/.well-known/host-meta") do
          get_template_from_xml(body)
        else
          e -> {:error, "Can't find LRDD template: #{inspect(e)}"}
        end
    end
  end

  defp get_address_from_domain(domain, encoded_account) when is_binary(domain) do
    case find_lrdd_template(domain) do
      {:ok, template} ->
        String.replace(template, "{uri}", encoded_account)

      _ ->
        "https://#{domain}/.well-known/webfinger?resource=#{encoded_account}"
    end
  end

  defp get_address_from_domain(_, _), do: nil

  @spec finger(String.t()) :: {:ok, map()} | {:error, any()}
  def finger(account) do
    account = String.trim_leading(account, "@")

    domain =
      with [_name, domain] <- String.split(account, "@") do
        domain
      else
        _e ->
          URI.parse(account).host
      end

    encoded_account = URI.encode("acct:#{account}")

    with address when is_binary(address) <- get_address_from_domain(domain, encoded_account),
         response <-
           HTTP.get(
             address,
             [{"accept", "application/xrd+xml,application/jrd+json"}]
           ),
         {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 <-
           response do
      case List.keyfind(headers, "content-type", 0) do
        {_, content_type} ->
          case Plug.Conn.Utils.media_type(content_type) do
            {:ok, "application", subtype, _} when subtype in ~w(xrd+xml xml) ->
              webfinger_from_xml(body)

            {:ok, "application", subtype, _} when subtype in ~w(jrd+json json) ->
              webfinger_from_json(body)

            _ ->
              {:error, {:content_type, content_type}}
          end

        _ ->
          {:error, {:content_type, nil}}
      end
    else
      e ->
        Logger.debug(fn -> "Couldn't finger #{account}" end)
        Logger.debug(fn -> inspect(e) end)
        {:error, e}
    end
  end
end
