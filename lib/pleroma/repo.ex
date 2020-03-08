# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo do
  use Ecto.Repo,
    otp_app: :pleroma,
    adapter: Ecto.Adapters.Postgres,
    migration_timestamps: [type: :naive_datetime_usec]

  require Logger

  defmodule Instrumenter do
    use Prometheus.EctoInstrumenter
  end

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc "find resource based on prepared query"
  @spec find_resource(Ecto.Query.t()) :: {:ok, struct()} | {:error, :not_found}
  def find_resource(%Ecto.Query{} = query) do
    case __MODULE__.one(query) do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end

  def find_resource(_query), do: {:error, :not_found}

  @doc """
  Gets association from cache or loads if need

  ## Examples

    iex> Repo.get_assoc(token, :user)
    %User{}

  """
  @spec get_assoc(struct(), atom()) :: {:ok, struct()} | {:error, :not_found}
  def get_assoc(resource, association) do
    case __MODULE__.preload(resource, association) do
      %{^association => assoc} when not is_nil(assoc) -> {:ok, assoc}
      _ -> {:error, :not_found}
    end
  end

  def check_migrations_applied!() do
    unless Pleroma.Config.get(
             [:i_am_aware_this_may_cause_data_loss, :disable_migration_check],
             false
           ) do
      Ecto.Migrator.with_repo(__MODULE__, fn repo ->
        down_migrations =
          Ecto.Migrator.migrations(repo)
          |> Enum.reject(fn
            {:up, _, _} -> true
            {:down, _, _} -> false
          end)

        if length(down_migrations) > 0 do
          down_migrations_text =
            Enum.map(down_migrations, fn {:down, id, name} -> "- #{name} (#{id})\n" end)

          Logger.error(
            "The following migrations were not applied:\n#{down_migrations_text}If you want to start Pleroma anyway, set\nconfig :pleroma, :i_am_aware_this_may_cause_data_loss, disable_migration_check: true"
          )

          raise Pleroma.Repo.UnappliedMigrationsError
        end
      end)
    else
      :ok
    end
  end
end

defmodule Pleroma.Repo.UnappliedMigrationsError do
  defexception message: "Unapplied Migrations detected"
end
