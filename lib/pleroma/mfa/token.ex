# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFA.Token do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Authorization

  @expires 300

  @type t() :: %__MODULE__{}

  schema "mfa_tokens" do
    field(:token, :string)
    field(:valid_until, :naive_datetime_usec)

    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:authorization, Authorization)

    timestamps()
  end

  @spec get_by_token(String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_by_token(token) do
    from(
      t in __MODULE__,
      where: t.token == ^token,
      preload: [:user, :authorization]
    )
    |> Repo.find_resource()
  end

  @spec validate(String.t()) :: {:ok, t()} | {:error, :not_found} | {:error, :expired_token}
  def validate(token_str) do
    with {:ok, token} <- get_by_token(token_str),
         false <- expired?(token) do
      {:ok, token}
    end
  end

  defp expired?(%__MODULE__{valid_until: valid_until}) do
    with true <- NaiveDateTime.diff(NaiveDateTime.utc_now(), valid_until) > 0 do
      {:error, :expired_token}
    end
  end

  @spec create(User.t(), Authorization.t() | nil) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(user, authorization \\ nil) do
    with {:ok, token} <- do_create(user, authorization) do
      Pleroma.Workers.PurgeExpiredToken.enqueue(%{
        token_id: token.id,
        valid_until: DateTime.from_naive!(token.valid_until, "Etc/UTC"),
        mod: __MODULE__
      })

      {:ok, token}
    end
  end

  defp do_create(user, authorization) do
    %__MODULE__{}
    |> change()
    |> assign_user(user)
    |> maybe_assign_authorization(authorization)
    |> put_token()
    |> put_valid_until()
    |> Repo.insert()
  end

  defp assign_user(changeset, user) do
    changeset
    |> put_assoc(:user, user)
    |> validate_required([:user])
  end

  defp maybe_assign_authorization(changeset, %Authorization{} = authorization) do
    changeset
    |> put_assoc(:authorization, authorization)
    |> validate_required([:authorization])
  end

  defp maybe_assign_authorization(changeset, _), do: changeset

  defp put_token(changeset) do
    token = Pleroma.Web.OAuth.Token.Utils.generate_token()

    changeset
    |> change(%{token: token})
    |> validate_required([:token])
    |> unique_constraint(:token)
  end

  defp put_valid_until(changeset) do
    expires_in = NaiveDateTime.add(NaiveDateTime.utc_now(), @expires)

    changeset
    |> change(%{valid_until: expires_in})
    |> validate_required([:valid_until])
  end
end
