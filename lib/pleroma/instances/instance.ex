# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.Instance do
  @moduledoc "Instance."

  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo

  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  schema "instances" do
    field(:host, :string)
    field(:unreachable_since, :naive_datetime_usec)

    timestamps()
  end

  defdelegate host(url_or_host), to: Instances

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:host, :unreachable_since])
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

  def reachable?(_), do: true

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

  defp parse_datetime(datetime) when is_binary(datetime) do
    NaiveDateTime.from_iso8601(datetime)
  end

  defp parse_datetime(datetime), do: datetime
end
