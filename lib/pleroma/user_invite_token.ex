defmodule Pleroma.UserInviteToken do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.{User, UserInviteToken, Repo}

  schema "user_invite_tokens" do
    field(:token, :string)
    field(:used, :boolean, default: false)

    timestamps()
  end

  def create_token do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()

    token = %UserInviteToken{
      used: false,
      token: token
    }

    Repo.insert(token)
  end

  def used_changeset(struct) do
    struct
    |> cast(%{}, [])
    |> put_change(:used, true)
  end

  def mark_as_used(token) do
    with %{used: false} = token <- Repo.get_by(UserInviteToken, %{token: token}),
         {:ok, token} <- Repo.update(used_changeset(token)) do
      {:ok, token}
    else
      _e -> {:error, token}
    end
  end
end
