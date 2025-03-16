# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.Instance do
  @moduledoc "Instance."

  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Maps
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Workers.DeleteWorker

  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  require Logger

  schema "instances" do
    field(:host, :string)
    field(:unreachable_since, :naive_datetime_usec)
    field(:favicon, :string)
    field(:favicon_updated_at, :naive_datetime)

    embeds_one :metadata, Pleroma.Instances.Metadata, primary_key: false do
      field(:software_name, :string)
      field(:software_version, :string)
      field(:software_repository, :string)
    end

    field(:metadata_updated_at, :utc_datetime)

    timestamps()
  end

  defdelegate host(url_or_host), to: Instances

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, __schema__(:fields) -- [:metadata])
    |> cast_embed(:metadata, with: &metadata_changeset/2)
    |> validate_required([:host])
    |> unique_constraint(:host)
  end

  def metadata_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:software_name, :software_version, :software_repository])
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
    %Instance{host: host(url_or_host)}
    |> changeset(%{unreachable_since: nil})
    |> Repo.insert(on_conflict: {:replace, [:unreachable_since]}, conflict_target: :host)
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
      Logger.warning("Instance.get_or_update_favicon(\"#{host}\") error: #{inspect(e)}")
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
        Logger.warning(
          "Instance.scrape_favicon(\"#{to_string(instance_uri)}\") error: #{inspect(e)}"
        )

        nil
    end
  end

  def get_or_update_metadata(%URI{host: host} = instance_uri) do
    existing_record = Repo.get_by(Instance, %{host: host})
    now = NaiveDateTime.utc_now()

    if existing_record && existing_record.metadata_updated_at &&
         NaiveDateTime.diff(now, existing_record.metadata_updated_at) < 86_400 do
      existing_record.metadata
    else
      metadata = scrape_metadata(instance_uri)

      if existing_record do
        existing_record
        |> changeset(%{metadata: metadata, metadata_updated_at: now})
        |> Repo.update()
      else
        %Instance{}
        |> changeset(%{host: host, metadata: metadata, metadata_updated_at: now})
        |> Repo.insert()
      end

      metadata
    end
  end

  defp get_nodeinfo_uri(well_known) do
    links = Map.get(well_known, "links", [])

    nodeinfo21 =
      Enum.find(links, &(&1["rel"] == "http://nodeinfo.diaspora.software/ns/schema/2.1"))["href"]

    nodeinfo20 =
      Enum.find(links, &(&1["rel"] == "http://nodeinfo.diaspora.software/ns/schema/2.0"))["href"]

    cond do
      is_binary(nodeinfo21) -> {:ok, nodeinfo21}
      is_binary(nodeinfo20) -> {:ok, nodeinfo20}
      true -> {:error, :no_links}
    end
  end

  defp scrape_metadata(%URI{} = instance_uri) do
    try do
      with {_, true} <- {:reachable, reachable?(instance_uri.host)},
           {:ok, %Tesla.Env{body: well_known_body}} <-
             instance_uri
             |> URI.merge("/.well-known/nodeinfo")
             |> to_string()
             |> Pleroma.HTTP.get([{"accept", "application/json"}]),
           {:ok, well_known_json} <- Jason.decode(well_known_body),
           {:ok, nodeinfo_uri} <- get_nodeinfo_uri(well_known_json),
           {:ok, %Tesla.Env{body: nodeinfo_body}} <-
             Pleroma.HTTP.get(nodeinfo_uri, [{"accept", "application/json"}]),
           {:ok, nodeinfo} <- Jason.decode(nodeinfo_body) do
        # Can extract more metadata from NodeInfo but need to be careful about it's size,
        # can't just dump the entire thing
        software = Map.get(nodeinfo, "software", %{})

        %{
          software_name: software["name"],
          software_version: software["version"]
        }
        |> Maps.put_if_present(:software_repository, software["repository"])
      else
        {:reachable, false} ->
          Logger.debug(
            "Instance.scrape_metadata(\"#{to_string(instance_uri)}\") ignored unreachable host"
          )

          nil

        _ ->
          nil
      end
    rescue
      e ->
        Logger.warning(
          "Instance.scrape_metadata(\"#{to_string(instance_uri)}\") error: #{inspect(e)}"
        )

        nil
    end
  end

  @doc """
  Deletes all users from an instance in a background task, thus also deleting
  all of those users' activities and notifications.
  """
  def delete_users_and_activities(host) when is_binary(host) do
    DeleteWorker.new(%{"op" => "delete_instance", "host" => host})
    |> Oban.insert()
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
