# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserInviteToken do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.UserInviteToken

  @type t :: %__MODULE__{}
  @type token :: String.t()

  schema "user_invite_tokens" do
    field(:token, :string)
    field(:used, :boolean, default: false)
    field(:max_use, :integer)
    field(:expires_at, :date)
    field(:uses, :integer, default: 0)
    field(:invite_type, :string)

    timestamps()
  end

  @spec create_invite(map()) :: {:ok, UserInviteToken.t()}
  def create_invite(params \\ %{}) do
    %UserInviteToken{}
    |> cast(params, [:max_use, :expires_at])
    |> add_token()
    |> assign_type()
    |> Repo.insert()
  end

  defp add_token(changeset) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
    put_change(changeset, :token, token)
  end

  defp assign_type(%{changes: %{max_use: _max_use, expires_at: _expires_at}} = changeset) do
    put_change(changeset, :invite_type, "reusable_date_limited")
  end

  defp assign_type(%{changes: %{expires_at: _expires_at}} = changeset) do
    put_change(changeset, :invite_type, "date_limited")
  end

  defp assign_type(%{changes: %{max_use: _max_use}} = changeset) do
    put_change(changeset, :invite_type, "reusable")
  end

  defp assign_type(changeset), do: put_change(changeset, :invite_type, "one_time")

  @spec list_invites() :: [UserInviteToken.t()]
  def list_invites do
    query = from(u in UserInviteToken, order_by: u.id)
    Repo.all(query)
  end

  @spec update_invite!(UserInviteToken.t(), map()) :: UserInviteToken.t() | no_return()
  def update_invite!(invite, changes) do
    change(invite, changes) |> Repo.update!()
  end

  @spec update_invite(UserInviteToken.t(), map()) ::
          {:ok, UserInviteToken.t()} | {:error, Changeset.t()}
  def update_invite(invite, changes) do
    change(invite, changes) |> Repo.update()
  end

  @spec find_by_token!(token()) :: UserInviteToken.t() | no_return()
  def find_by_token!(token), do: Repo.get_by!(UserInviteToken, token: token)

  @spec find_by_token(token()) :: {:ok, UserInviteToken.t()} | nil
  def find_by_token(token) do
    with %UserInviteToken{} = invite <- Repo.get_by(UserInviteToken, token: token) do
      {:ok, invite}
    end
  end

  @spec valid_invite?(UserInviteToken.t()) :: boolean()
  def valid_invite?(%{invite_type: "one_time"} = invite) do
    not invite.used
  end

  def valid_invite?(%{invite_type: "date_limited"} = invite) do
    not_overdue_date?(invite) and not invite.used
  end

  def valid_invite?(%{invite_type: "reusable"} = invite) do
    invite.uses < invite.max_use and not invite.used
  end

  def valid_invite?(%{invite_type: "reusable_date_limited"} = invite) do
    not_overdue_date?(invite) and invite.uses < invite.max_use and not invite.used
  end

  defp not_overdue_date?(%{expires_at: expires_at}) do
    Date.compare(Date.utc_today(), expires_at) in [:lt, :eq]
  end

  @spec update_usage!(UserInviteToken.t()) :: nil | UserInviteToken.t() | no_return()
  def update_usage!(%{invite_type: "date_limited"}), do: nil

  def update_usage!(%{invite_type: "one_time"} = invite),
    do: update_invite!(invite, %{used: true})

  def update_usage!(%{invite_type: invite_type} = invite)
      when invite_type == "reusable" or invite_type == "reusable_date_limited" do
    changes = %{
      uses: invite.uses + 1
    }

    changes =
      if changes.uses >= invite.max_use do
        Map.put(changes, :used, true)
      else
        changes
      end

    update_invite!(invite, changes)
  end
end
