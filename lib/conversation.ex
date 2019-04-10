# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation do
  alias Pleroma.Repo
  alias Pleroma.Conversation.Participation
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field(:ap_id, :string)
    has_many(:participations, Participation)

    timestamps()
  end

  def creation_cng(struct, params) do
    struct
    |> cast(params, [:ap_id])
    |> validate_required([:ap_id])
    |> unique_constraint(:ap_id)
  end

  def create_for_ap_id(ap_id) do
    %__MODULE__{}
    |> creation_cng(%{ap_id: ap_id})
    |> Repo.insert()
  end
end
