# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger do
  alias Pleroma.HTTP
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.Web.XML
  alias Pleroma.XmlBuilder
  require Jason
  require Logger

  def host_meta do
    base_url = Web.base_url()

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

  def represent_user(user, "JSON") do
    {:ok, user} = User.ensure_keys_present(user)

    %{
      "subject" => "acct:#{user.nickname}@#{Pleroma.Web.Endpoint.host()}",
      "aliases" => [user.ap_id],
      "links" => gather_links(user)
    }
  end

  def represent_user(user, "XML") do
    {:ok, user} = User.ensure_keys_present(user)

    links =
      gather_links(user)
      |> Enum.map(fn link -> {:Link, link} end)

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{Pleroma.Web.Endpoint.host()}"},
        {:Alias, user.ap_id}
      ] ++ links
    }
    |> XmlBuilder.to_doc()
  end

  defp get_magic_key("data:application/magic-public-key," <> magic_key) do
    {:ok, magic_key}
  end

  defp get_magic_key(nil) do
    Logger.debug("Undefined magic key.")
    {:ok, nil}
  end

  defp get_magic_key(_) do
    {:error, "Missing magic key data."}
  end

  defp webfinger_from_xml(doc) do
    with magic_key <- XML.string_from_xpath(~s{//Link[@rel="magic-public-key"]/@href}, doc),
         {:ok, magic_key} <- get_magic_key(magic_key),
         topic <-
           XML.string_from_xpath(
             ~s{//Link[@rel="http://schemas.google.com/g/2010#updates-from"]/@href},
             doc
           ),
         subject <- XML.string_from_xpath("//Subject", doc),
         subscribe_address <-
           XML.string_from_xpath(
             ~s{//Link[@rel="http://ostatus.org/schema/1.0/subscribe"]/@template},
             doc
           ),
         ap_id <-
           XML.string_from_xpath(
             ~s{//Link[@rel="self" and @type="application/activity+json"]/@href},
             doc
           ) do
      data = %{
        "magic_key" => magic_key,
        "topic" => topic,
        "subject" => subject,
        "subscribe_address" => subscribe_address,
        "ap_id" => ap_id
      }

      {:ok, data}
    else
      {:error, e} ->
        {:error, e}

      e ->
        {:error, e}
    end
  end

  defp webfinger_from_json(doc) do
    data =
      Enum.reduce(doc["links"], %{"subject" => doc["subject"]}, fn link, data ->
        case {link["type"], link["rel"]} do
          {"application/activity+json", "self"} ->
            Map.put(data, "ap_id", link["href"])

          {"application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"", "self"} ->
            Map.put(data, "ap_id", link["href"])

          {_, "http://ostatus.org/schema/1.0/subscribe"} ->
            Map.put(data, "subscribe_address", link["template"])

          _ ->
            Logger.debug("Unhandled type: #{inspect(link["type"])}")
            data
        end
      end)

    {:ok, data}
  end

  def get_template_from_xml(body) do
    xpath = "//Link[@rel='lrdd']/@template"

    with doc when doc != :error <- XML.parse_document(body),
         template when template != nil <- XML.string_from_xpath(xpath, doc) do
      {:ok, template}
    end
  end

  def find_lrdd_template(domain) do
    with {:ok, %{status: status, body: body}} when status in 200..299 <-
           HTTP.get("http://#{domain}/.well-known/host-meta", []) do
      get_template_from_xml(body)
    else
      _ ->
        with {:ok, %{body: body}} <- HTTP.get("https://#{domain}/.well-known/host-meta", []) do
          get_template_from_xml(body)
        else
          e -> {:error, "Can't find LRDD template: #{inspect(e)}"}
        end
    end
  end

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

    address =
      case find_lrdd_template(domain) do
        {:ok, template} ->
          String.replace(template, "{uri}", URI.encode(account))

        _ ->
          "https://#{domain}/.well-known/webfinger?resource=acct:#{account}"
      end

    with response <-
           HTTP.get(
             address,
             Accept: "application/xrd+xml,application/jrd+json"
           ),
         {:ok, %{status: status, body: body}} when status in 200..299 <- response do
      doc = XML.parse_document(body)

      if doc != :error do
        webfinger_from_xml(doc)
      else
        with {:ok, doc} <- Jason.decode(body) do
          webfinger_from_json(doc)
        end
      end
    else
      e ->
        Logger.debug(fn -> "Couldn't finger #{account}" end)
        Logger.debug(fn -> inspect(e) end)
        {:error, e}
    end
  end
end
