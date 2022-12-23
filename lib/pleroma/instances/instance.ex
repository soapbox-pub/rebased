# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.Instance do
  @moduledoc "Instance."

  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Workers.BackgroundWorker

  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  require Logger

  schema "instances" do
    field(:host, :string)
    field(:unreachable_since, :naive_datetime_usec)
    field(:favicon, :string)
    field(:favicon_updated_at, :naive_datetime)

    timestamps()
  end

  defdelegate host(url_or_host), to: Instances

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:host, :unreachable_since, :favicon, :favicon_updated_at])
    |> validate_required([:host])
    |> unique_constraint(:host)
  end

  def filter_reachable([]), do: %{}

  def filter_reachable(urls_or_hosts) when is_list(urls_or_hosts) do
    hosts =
      urls_or_hosts
      |> Enum.map(&(&1 && host(&1)))
      |> Enum.filter(&(to_string(&1) != ""))

    unreachable_since_by_host =
      Repo.all(
        from(i in Instance,
          where: i.host in ^hosts,
          select: {i.host, i.unreachable_since}
        )
      )
      |> Map.new(& &1)

    reachability_datetime_threshold = Instances.reachability_datetime_threshold()

    for entry <- Enum.filter(urls_or_hosts, &is_binary/1) do
      host = host(entry)
      unreachable_since = unreachable_since_by_host[host]

      if !unreachable_since ||
           NaiveDateTime.compare(unreachable_since, reachability_datetime_threshold) == :gt do
        {entry, unreachable_since}
      end
    end
    |> Enum.filter(& &1)
    |> Map.new(& &1)
  end

  def reachable?(url_or_host) when is_binary(url_or_host) do
    !Repo.one(
      from(i in Instance,
        where:
          i.host == ^host(url_or_host) and
            i.unreachable_since <= ^Instances.reachability_datetime_threshold(),
        select: true
      )
    )
  end

  def reachable?(url_or_host) when is_binary(url_or_host), do: true

  def set_reachable(url_or_host) when is_binary(url_or_host) do
    with host <- host(url_or_host),
         %Instance{} = existing_record <- Repo.get_by(Instance, %{host: host}) do
      {:ok, _instance} =
        existing_record
        |> changeset(%{unreachable_since: nil})
        |> Repo.update()
    end
  end

  def set_reachable(_), do: {:error, nil}

  def set_unreachable(url_or_host, unreachable_since \\ nil)

  def set_unreachable(url_or_host, unreachable_since) when is_binary(url_or_host) do
    unreachable_since = parse_datetime(unreachable_since) || NaiveDateTime.utc_now()
    host = host(url_or_host)
    existing_record = Repo.get_by(Instance, %{host: host})

    changes = %{unreachable_since: unreachable_since}

    cond do
      is_nil(existing_record) ->
        %Instance{}
        |> changeset(Map.put(changes, :host, host))
        |> Repo.insert()

      existing_record.unreachable_since &&
          NaiveDateTime.compare(existing_record.unreachable_since, unreachable_since) != :gt ->
        {:ok, existing_record}

      true ->
        existing_record
        |> changeset(changes)
        |> Repo.update()
    end
  end

  def set_unreachable(_, _), do: {:error, nil}

  def get_consistently_unreachable do
    reachability_datetime_threshold = Instances.reachability_datetime_threshold()

    from(i in Instance,
      where: ^reachability_datetime_threshold > i.unreachable_since,
      order_by: i.unreachable_since,
      select: {i.host, i.unreachable_since}
    )
    |> Repo.all()
  end

  defp parse_datetime(datetime) when is_binary(datetime) do
    NaiveDateTime.from_iso8601(datetime)
  end

  defp parse_datetime(datetime), do: datetime

  def get_or_update_favicon(%URI{host: host} = instance_uri) do
    existing_record = Repo.get_by(Instance, %{host: host})
    now = NaiveDateTime.utc_now()

    if existing_record && existing_record.favicon_updated_at &&
         NaiveDateTime.diff(now, existing_record.favicon_updated_at) < 86_400 do
      existing_record.favicon
    else
      favicon = scrape_favicon(instance_uri)

      if existing_record do
        existing_record
        |> changeset(%{favicon: favicon, favicon_updated_at: now})
        |> Repo.update()
      else
        %Instance{}
        |> changeset(%{host: host, favicon: favicon, favicon_updated_at: now})
        |> Repo.insert()
      end

      favicon
    end
  rescue
    e ->
      Logger.warn("Instance.get_or_update_favicon(\"#{host}\") error: #{inspect(e)}")
      nil
  end

  defp scrape_favicon(%URI{} = instance_uri) do
    try do
      with {_, true} <- {:reachable, reachable?(instance_uri.host)},
           {:ok, %Tesla.Env{body: html}} <-
             Pleroma.HTTP.get(to_string(instance_uri), [{"accept", "text/html"}], pool: :media),
           {_, [favicon_rel | _]} when is_binary(favicon_rel) <-
             {:parse,
              html |> Floki.parse_document!() |> Floki.attribute("link[rel=icon]", "href")},
           {_, favicon} when is_binary(favicon) <-
             {:merge, URI.merge(instance_uri, favicon_rel) |> to_string()} do
        favicon
      else
        {:reachable, false} ->
          Logger.debug(
            "Instance.scrape_favicon(\"#{to_string(instance_uri)}\") ignored unreachable host"
          )

          nil

        _ ->
          nil
      end
    rescue
      e ->
        Logger.warn(
          "Instance.scrape_favicon(\"#{to_string(instance_uri)}\") error: #{inspect(e)}"
        )

        nil
    end
  end

  @doc """
  Deletes all users from an instance in a background task, thus also deleting
  all of those users' activities and notifications.
  """
  def delete_users_and_activities(host) when is_binary(host) do
    BackgroundWorker.enqueue("delete_instance", %{"host" => host})
  end

  def perform(:delete_instance, host) when is_binary(host) do
    User.Query.build(%{nickname: "@#{host}"})
    |> Repo.chunk_stream(100, :batches)
    |> Stream.each(fn users ->
      users
      |> Enum.each(fn user ->
        User.perform(:delete, user)
      end)
    end)
    |> Stream.run()
  end
end
