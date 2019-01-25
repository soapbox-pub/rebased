defmodule Pleroma.Instances.Instance do
  @moduledoc "Instance."

  alias Pleroma.Instances
  alias Pleroma.Instances.Instance

  use Ecto.Schema

  import Ecto.{Query, Changeset}

  alias Pleroma.Repo

  schema "instances" do
    field(:host, :string)
    field(:unreachable_since, :naive_datetime)
    field(:reachability_checked_at, :naive_datetime)

    timestamps()
  end

  defdelegate host(url), to: Instances

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:host, :unreachable_since, :reachability_checked_at])
    |> validate_required([:host])
    |> unique_constraint(:host)
  end

  def filter_reachable([]), do: []

  def filter_reachable(urls) when is_list(urls) do
    hosts =
      urls
      |> Enum.map(&(&1 && host(&1)))
      |> Enum.filter(&(to_string(&1) != ""))

    unreachable_hosts =
      Repo.all(
        from(i in Instance,
          where:
            i.host in ^hosts and
              i.unreachable_since <= ^Instances.reachability_datetime_threshold(),
          select: i.host
        )
      )

    Enum.filter(urls, &(&1 && host(&1) not in unreachable_hosts))
  end

  def reachable?(url) when is_binary(url) do
    !Repo.one(
      from(i in Instance,
        where:
          i.host == ^host(url) and
            i.unreachable_since <= ^Instances.reachability_datetime_threshold(),
        select: true
      )
    )
  end

  def reachable?(_), do: true

  def set_reachable(url) when is_binary(url) do
    with host <- host(url),
         %Instance{} = existing_record <- Repo.get_by(Instance, %{host: host}) do
      {:ok, _instance} =
        existing_record
        |> changeset(%{unreachable_since: nil, reachability_checked_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def set_reachable(_), do: {0, :noop}

  def set_unreachable(url, unreachable_since \\ nil)

  def set_unreachable(url, unreachable_since) when is_binary(url) do
    unreachable_since = unreachable_since || DateTime.utc_now()
    host = host(url)
    existing_record = Repo.get_by(Instance, %{host: host})

    changes = %{
      unreachable_since: unreachable_since,
      reachability_checked_at: NaiveDateTime.utc_now()
    }

    if existing_record do
      update_changes =
        if existing_record.unreachable_since &&
             NaiveDateTime.compare(existing_record.unreachable_since, unreachable_since) != :gt,
           do: Map.delete(changes, :unreachable_since),
           else: changes

      {:ok, _instance} =
        existing_record
        |> changeset(update_changes)
        |> Repo.update()
    else
      {:ok, _instance} =
        %Instance{}
        |> changeset(Map.put(changes, :host, host))
        |> Repo.insert()
    end
  end

  def set_unreachable(_, _), do: {0, :noop}
end
