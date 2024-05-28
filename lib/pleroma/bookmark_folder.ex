# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BookmarkFolder do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.BookmarkFolder
  alias Pleroma.Emoji
  alias Pleroma.Repo
  alias Pleroma.User

  @type t :: %__MODULE__{}
  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "bookmark_folders" do
    field(:name, :string)
    field(:emoji, :string)

    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def get_by_id(id), do: Repo.get_by(BookmarkFolder, id: id)

  def create(user_id, name, emoji \\ nil) do
    %BookmarkFolder{}
    |> cast(
      %{
        user_id: user_id,
        name: name,
        emoji: emoji
      },
      [:user_id, :name, :emoji]
    )
    |> validate_required([:user_id, :name])
    |> fix_emoji()
    |> validate_emoji()
    |> unique_constraint([:user_id, :name])
    |> Repo.insert()
  end

  def update(folder_id, name, emoji \\ nil) do
    get_by_id(folder_id)
    |> cast(
      %{
        name: name,
        emoji: emoji
      },
      [:name, :emoji]
    )
    |> fix_emoji()
    |> validate_emoji()
    |> unique_constraint([:user_id, :name])
    |> Repo.update()
  end

  defp fix_emoji(changeset) do
    with {:emoji_field, emoji} when is_binary(emoji) <-
           {:emoji_field, get_field(changeset, :emoji)},
         {:fixed_emoji, emoji} <-
           {:fixed_emoji,
            emoji
            |> Pleroma.Emoji.fully_qualify_emoji()
            |> Pleroma.Emoji.maybe_quote()} do
      put_change(changeset, :emoji, emoji)
    else
      {:emoji_field, _} -> changeset
    end
  end

  defp validate_emoji(changeset) do
    validate_change(changeset, :emoji, fn
      :emoji, nil ->
        []

      :emoji, emoji ->
        if Emoji.unicode?(emoji) or valid_local_custom_emoji?(emoji) do
          []
        else
          [emoji: "Invalid emoji"]
        end
    end)
  end

  defp valid_local_custom_emoji?(emoji) do
    with %{file: _path} <- Emoji.get(emoji) do
      true
    else
      _ -> false
    end
  end

  def delete(folder_id) do
    BookmarkFolder
    |> Repo.get_by(id: folder_id)
    |> Repo.delete()
  end

  def for_user(user_id) do
    BookmarkFolder
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  def belongs_to_user?(folder_id, user_id) do
    BookmarkFolder
    |> where(id: ^folder_id, user_id: ^user_id)
    |> Repo.exists?()
  end
end
