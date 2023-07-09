# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Webhook do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Repo

  @event_types [:"account.created", :"report.created"]

  schema "webhooks" do
    field(:url, ObjectValidators.Uri)
    field(:events, {:array, Ecto.Enum}, values: @event_types, default: [])
    field(:secret, :string, default: "")
    field(:enabled, :boolean, default: true)
    field(:internal, :boolean, default: false)

    timestamps()
  end

  def get(id), do: Repo.get(__MODULE__, id)

  def get_by_type(type) do
    __MODULE__
    |> where([w], ^type in w.events)
    |> Repo.all()
  end

  def changeset(%__MODULE__{} = webhook, params) do
    webhook
    |> cast(params, [:url, :events, :enabled, :internal])
    |> validate_required([:url, :events])
    |> unique_constraint(:url)
    |> strip_events()
    |> put_secret()
  end

  def update_changeset(%__MODULE__{} = webhook, params \\ %{}) do
    webhook
    |> cast(params, [:url, :events, :enabled, :internal])
    |> unique_constraint(:url)
    |> strip_events()
  end

  def create(params) do
    {:ok, webhook} =
      %__MODULE__{}
      |> changeset(params)
      |> Repo.insert()

    webhook
  end

  def update(%__MODULE__{} = webhook, params) do
    {:ok, webhook} =
      webhook
      |> update_changeset(params)
      |> Repo.update()

    webhook
  end

  def delete(webhook), do: webhook |> Repo.delete()

  def rotate_secret(%__MODULE__{} = webhook) do
    webhook
    |> cast(%{}, [])
    |> put_secret()
    |> Repo.update()
  end

  def set_enabled(%__MODULE__{} = webhook, enabled) do
    webhook
    |> cast(%{enabled: enabled}, [:enabled])
    |> Repo.update()
  end

  defp strip_events(params) do
    if Map.has_key?(params, :events) do
      params
      |> Map.put(:events, Enum.filter(params[:events], &Enum.member?(@event_types, &1)))
    else
      params
    end
  end

  defp put_secret(changeset) do
    changeset
    |> put_change(:secret, generate_secret())
  end

  defp generate_secret do
    Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)
  end
end
