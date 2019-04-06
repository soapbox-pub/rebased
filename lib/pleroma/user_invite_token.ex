# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserInviteToken do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.UserInviteToken

  @type token :: String.t()

  schema "user_invite_tokens" do
    field(:token, :string)
    field(:used, :boolean, default: false)
    field(:max_use, :integer)
    field(:expire_at, :date)
    field(:uses, :integer)
    field(:token_type)

    timestamps()
  end

  def create_token(options \\ []) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()

    max_use = options[:max_use]
    expire_at = options[:expire_at]

    token =
      %UserInviteToken{
        used: false,
        token: token,
        max_use: max_use,
        expire_at: expire_at,
        uses: 0
      }
      |> token_type()

    Repo.insert(token)
  end

  def list_invites do
    query = from(u in UserInviteToken, order_by: u.id)
    Repo.all(query)
  end

  def used_changeset(struct) do
    struct
    |> cast(%{}, [])
    |> put_change(:used, true)
  end

  @spec mark_as_used(token()) :: {:ok, UserInviteToken.t()} | {:error, token()}
  def mark_as_used(token) do
    with %{used: false} = token <- Repo.get_by(UserInviteToken, %{token: token}),
         {:ok, token} <- Repo.update(used_changeset(token)) do
      {:ok, token}
    else
      _e -> {:error, token}
    end
  end

  defp token_type(%{expire_at: nil, max_use: nil} = token), do: %{token | token_type: "one_time"}

  defp token_type(%{expire_at: _expire_at, max_use: nil} = token),
    do: %{token | token_type: "date_limited"}

  defp token_type(%{expire_at: nil, max_use: _max_use} = token),
    do: %{token | token_type: "reusable"}

  defp token_type(%{expire_at: _expire_at, max_use: _max_use} = token),
    do: %{token | token_type: "reusable_date_limited"}

  @spec valid_token?(UserInviteToken.t()) :: boolean()
  def valid_token?(%{token_type: "one_time"} = token) do
    not token.used
  end

  def valid_token?(%{token_type: "date_limited"} = token) do
    not_overdue_date?(token) and not token.used
  end

  def valid_token?(%{token_type: "reusable"} = token) do
    token.uses < token.max_use and not token.used
  end

  def valid_token?(%{token_type: "reusable_date_limited"} = token) do
    not_overdue_date?(token) and token.uses < token.max_use and not token.used
  end

  defp not_overdue_date?(%{expire_at: expire_at} = token) do
    Date.compare(Date.utc_today(), expire_at) in [:lt, :eq] ||
      (Repo.update!(change(token, used: true)) && false)
  end

  def update_usage(%{token_type: "date_limited"}), do: nil

  def update_usage(%{token_type: "one_time"} = token) do
    UserInviteToken.mark_as_used(token.token)
  end

  def update_usage(%{token_type: token_type} = token)
      when token_type == "reusable" or token_type == "reusable_date_limited" do
    new_uses = token.uses + 1

    changes = %{
      uses: new_uses
    }

    changes =
      if new_uses >= token.max_use do
        Map.put(changes, :used, true)
      else
        changes
      end

    change(token, changes) |> Repo.update!()
  end
end
