# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gopher.Server do
  use GenServer
  require Logger

  def start_link(_) do
    config = Pleroma.Config.get(:gopher, [])
    ip = Keyword.get(config, :ip, {0, 0, 0, 0})
    port = Keyword.get(config, :port, 1234)

    if Keyword.get(config, :enabled, false) do
      GenServer.start_link(__MODULE__, [ip, port], [])
    else
      Logger.info("Gopher server disabled")
      :ignore
    end
  end

  def init([ip, port]) do
    Logger.info("Starting gopher server on #{port}")

    :ranch.start_listener(
      :gopher,
      100,
      :ranch_tcp,
      [ip: ip, port: port],
      __MODULE__.ProtocolHandler,
      []
    )

    {:ok, %{ip: ip, port: port}}
  end
end

defmodule Pleroma.Gopher.Server.ProtocolHandler do
  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
    {:ok, pid}
  end

  def init(ref, socket, transport, [] = _Opts) do
    :ok = :ranch.accept_ack(ref)
    loop(socket, transport)
  end

  def info(text) do
    text = String.replace(text, ~r/[\t\n]/, "")

    String.split(text, "\r")
    |> Enum.map(fn text ->
      "i#{text}\tfake\t(NULL)\t0\r\n"
    end)
    |> Enum.join("")
  end

  def link(name, selector, type \\ 1) do
    address = Pleroma.Web.Endpoint.host()
    port = Pleroma.Config.get([:gopher, :port], 1234)
    dstport = Pleroma.Config.get([:gopher, :dstport], port)
    "#{type}#{name}\t#{selector}\t#{address}\t#{dstport}\r\n"
  end

  def render_activities(activities) do
    activities
    |> Enum.reverse()
    |> Enum.map(fn activity ->
      user = User.get_cached_by_ap_id(activity.data["actor"])

      object = Object.normalize(activity)
      like_count = object.data["like_count"] || 0
      announcement_count = object.data["announcement_count"] || 0

      link("Post ##{activity.id} by #{user.nickname}", "/notices/#{activity.id}") <>
        info("#{like_count} likes, #{announcement_count} repeats") <>
        "i\tfake\t(NULL)\t0\r\n" <>
        info(HTML.strip_tags(String.replace(object.data["content"], "<br>", "\r")))
    end)
    |> Enum.join("i\tfake\t(NULL)\t0\r\n")
  end

  def response("") do
    info("Welcome to #{Pleroma.Config.get([:instance, :name], "Pleroma")}!") <>
      link("Public Timeline", "/main/public") <>
      link("Federated Timeline", "/main/all") <> ".\r\n"
  end

  def response("/main/public") do
    posts =
      ActivityPub.fetch_public_activities(%{"type" => ["Create"], "local_only" => true})
      |> render_activities

    info("Welcome to the Public Timeline!") <> posts <> ".\r\n"
  end

  def response("/main/all") do
    posts =
      ActivityPub.fetch_public_activities(%{"type" => ["Create"]})
      |> render_activities

    info("Welcome to the Federated Timeline!") <> posts <> ".\r\n"
  end

  def response("/notices/" <> id) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         true <- Visibility.is_public?(activity) do
      activities =
        ActivityPub.fetch_activities_for_context(activity.data["context"])
        |> render_activities

      user = User.get_cached_by_ap_id(activity.data["actor"])

      info("Post #{activity.id} by #{user.nickname}") <>
        link("More posts by #{user.nickname}", "/users/#{user.nickname}") <> activities <> ".\r\n"
    else
      _e ->
        info("Not public") <> ".\r\n"
    end
  end

  def response("/users/" <> nickname) do
    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      params = %{
        "type" => ["Create"],
        "actor_id" => user.ap_id
      }

      activities =
        ActivityPub.fetch_public_activities(params)
        |> render_activities

      info("Posts by #{user.nickname}") <> activities <> ".\r\n"
    else
      _e ->
        info("No such user") <> ".\r\n"
    end
  end

  def loop(socket, transport) do
    case transport.recv(socket, 0, 5000) do
      {:ok, data} ->
        data = String.trim_trailing(data, "\r\n")
        transport.send(socket, response(data))
        :ok = transport.close(socket)

      _ ->
        :ok = transport.close(socket)
    end
  end
end
