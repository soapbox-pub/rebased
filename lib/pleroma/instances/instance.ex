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

  def update_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:host, :unreachable_since, :reachability_checked_at])
    |> unique_constraint(:host)
  end

  def reachable?(url) when is_binary(url) do
    !Repo.one(
      from(i in Instance,
        where:
          i.host == ^host(url) and i.unreachable_since <= ^Instances.reachability_time_threshold(),
        select: true
      )
    )
  end

  def reachable?(_), do: true

  def set_reachable(url) when is_binary(url) do
    Repo.update_all(
      from(i in Instance, where: i.host == ^host(url)),
      set: [
        unreachable_since: nil,
        reachability_checked_at: DateTime.utc_now()
      ]
    )
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

      {:ok, _instance} = Repo.update(update_changeset(existing_record, update_changes))
    else
      {:ok, _instance} = Repo.insert(update_changeset(%Instance{}, Map.put(changes, :host, host)))
    end
  end

  def set_unreachable(_, _), do: {0, :noop}

  defp host(url_or_host) do
    if url_or_host =~ ~r/^http/i do
      URI.parse(url_or_host).host
    else
      url_or_host
    end
  end
end
