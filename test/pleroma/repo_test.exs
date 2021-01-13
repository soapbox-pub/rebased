# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.RepoTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  alias Pleroma.User

  describe "find_resource/1" do
    test "returns user" do
      user = insert(:user)
      query = from(t in User, where: t.id == ^user.id)
      assert Repo.find_resource(query) == {:ok, user}
    end

    test "returns not_found" do
      query = from(t in User, where: t.id == ^"9gBuXNpD2NyDmmxxdw")
      assert Repo.find_resource(query) == {:error, :not_found}
    end
  end

  describe "get_assoc/2" do
    test "get assoc from preloaded data" do
      user = %User{name: "Agent Smith"}
      token = %Pleroma.Web.OAuth.Token{insert(:oauth_token) | user: user}
      assert Repo.get_assoc(token, :user) == {:ok, user}
    end

    test "get one-to-one assoc from repo" do
      user = insert(:user, name: "Jimi Hendrix")
      token = refresh_record(insert(:oauth_token, user: user))

      assert Repo.get_assoc(token, :user) == {:ok, user}
    end

    test "get one-to-many assoc from repo" do
      user = insert(:user)

      notification =
        refresh_record(insert(:notification, user: user, activity: insert(:note_activity)))

      assert Repo.get_assoc(user, :notifications) == {:ok, [notification]}
    end

    test "return error if has not assoc " do
      token = insert(:oauth_token, user: nil)
      assert Repo.get_assoc(token, :user) == {:error, :not_found}
    end
  end

  describe "chunk_stream/3" do
    test "fetch records one-by-one" do
      users = insert_list(50, :user)

      {fetch_users, 50} =
        from(t in User)
        |> Repo.chunk_stream(5)
        |> Enum.reduce({[], 0}, fn %User{} = user, {acc, count} ->
          {acc ++ [user], count + 1}
        end)

      assert users == fetch_users
    end

    test "fetch records in bulk" do
      users = insert_list(50, :user)

      {fetch_users, 10} =
        from(t in User)
        |> Repo.chunk_stream(5, :batches)
        |> Enum.reduce({[], 0}, fn users, {acc, count} ->
          {acc ++ users, count + 1}
        end)

      assert users == fetch_users
    end
  end
end
