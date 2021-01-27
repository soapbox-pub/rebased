# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserSearchTest do
  alias Pleroma.Repo
  alias Pleroma.User
  use Pleroma.DataCase

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "User.search" do
    setup do: clear_config([:instance, :limit_to_local_content])

    test "returns a resolved user as the first result" do
      clear_config([:instance, :limit_to_local_content], false)
      user = insert(:user, %{nickname: "no_relation", ap_id: "https://lain.com/users/lain"})
      _user = insert(:user, %{nickname: "com_user"})

      [first_user, _second_user] = User.search("https://lain.com/users/lain", resolve: true)

      assert first_user.id == user.id
    end

    test "returns a user with matching ap_id as the first result" do
      user = insert(:user, %{nickname: "no_relation", ap_id: "https://lain.com/users/lain"})
      _user = insert(:user, %{nickname: "com_user"})

      [first_user, _second_user] = User.search("https://lain.com/users/lain")

      assert first_user.id == user.id
    end

    test "doesn't die if two users have the same uri" do
      insert(:user, %{uri: "https://gensokyo.2hu/@raymoo"})
      insert(:user, %{uri: "https://gensokyo.2hu/@raymoo"})
      assert [_first_user, _second_user] = User.search("https://gensokyo.2hu/@raymoo")
    end

    test "returns a user with matching uri as the first result" do
      user =
        insert(:user, %{
          nickname: "no_relation",
          ap_id: "https://lain.com/users/lain",
          uri: "https://lain.com/@lain"
        })

      _user = insert(:user, %{nickname: "com_user"})

      [first_user, _second_user] = User.search("https://lain.com/@lain")

      assert first_user.id == user.id
    end

    test "excludes invisible users from results" do
      user = insert(:user, %{nickname: "john t1000"})
      insert(:user, %{invisible: true, nickname: "john t800"})

      [found_user] = User.search("john")
      assert found_user.id == user.id
    end

    # Note: as in Mastodon, `is_discoverable` doesn't anyhow relate to user searchability
    test "includes non-discoverable users in results" do
      insert(:user, %{nickname: "john 3000", is_discoverable: false})
      insert(:user, %{nickname: "john 3001"})

      users = User.search("john")
      assert Enum.count(users) == 2
    end

    test "excludes service actors from results" do
      insert(:user, actor_type: "Application", nickname: "user1")
      service = insert(:user, actor_type: "Service", nickname: "user2")
      person = insert(:user, actor_type: "Person", nickname: "user3")

      assert [found_user1, found_user2] = User.search("user")
      assert [found_user1.id, found_user2.id] -- [service.id, person.id] == []
    end

    test "accepts limit parameter" do
      Enum.each(0..4, &insert(:user, %{nickname: "john#{&1}"}))
      assert length(User.search("john", limit: 3)) == 3
      assert length(User.search("john")) == 5
    end

    test "accepts offset parameter" do
      Enum.each(0..4, &insert(:user, %{nickname: "john#{&1}"}))
      assert length(User.search("john", limit: 3)) == 3
      assert length(User.search("john", limit: 3, offset: 3)) == 2
    end

    defp clear_virtual_fields(user) do
      Map.merge(user, %{search_rank: nil, search_type: nil})
    end

    test "finds a user by full nickname or its leading fragment" do
      user = insert(:user, %{nickname: "john"})

      Enum.each(["john", "jo", "j"], fn query ->
        assert user ==
                 User.search(query)
                 |> List.first()
                 |> clear_virtual_fields()
      end)
    end

    test "finds a user by full name or leading fragment(s) of its words" do
      user = insert(:user, %{name: "John Doe"})

      Enum.each(["John Doe", "JOHN", "doe", "j d", "j", "d"], fn query ->
        assert user ==
                 User.search(query)
                 |> List.first()
                 |> clear_virtual_fields()
      end)
    end

    test "matches by leading fragment of user domain" do
      user = insert(:user, %{nickname: "arandom@dude.com"})
      insert(:user, %{nickname: "iamthedude"})

      assert [user.id] == User.search("dud") |> Enum.map(& &1.id)
    end

    test "ranks full nickname match higher than full name match" do
      nicknamed_user = insert(:user, %{nickname: "hj@shigusegubu.club"})
      named_user = insert(:user, %{nickname: "xyz@sample.com", name: "HJ"})

      results = User.search("hj")

      assert [nicknamed_user.id, named_user.id] == Enum.map(results, & &1.id)
      assert Enum.at(results, 0).search_rank > Enum.at(results, 1).search_rank
    end

    test "finds users, considering density of matched tokens" do
      u1 = insert(:user, %{name: "Bar Bar plus Word Word"})
      u2 = insert(:user, %{name: "Word Word Bar Bar Bar"})

      assert [u2.id, u1.id] == Enum.map(User.search("bar word"), & &1.id)
    end

    test "finds users, boosting ranks of friends and followers" do
      u1 = insert(:user)
      u2 = insert(:user, %{name: "Doe"})
      follower = insert(:user, %{name: "Doe"})
      friend = insert(:user, %{name: "Doe"})

      {:ok, follower, u1} = User.follow(follower, u1)
      {:ok, u1, friend} = User.follow(u1, friend)

      assert [friend.id, follower.id, u2.id] --
               Enum.map(User.search("doe", resolve: false, for_user: u1), & &1.id) == []
    end

    test "finds followings of user by partial name" do
      lizz = insert(:user, %{name: "Lizz"})
      jimi = insert(:user, %{name: "Jimi"})
      following_lizz = insert(:user, %{name: "Jimi Hendrix"})
      following_jimi = insert(:user, %{name: "Lizz Wright"})
      follower_lizz = insert(:user, %{name: "Jimi"})

      {:ok, lizz, following_lizz} = User.follow(lizz, following_lizz)
      {:ok, _jimi, _following_jimi} = User.follow(jimi, following_jimi)
      {:ok, _follower_lizz, _lizz} = User.follow(follower_lizz, lizz)

      assert Enum.map(User.search("jimi", following: true, for_user: lizz), & &1.id) == [
               following_lizz.id
             ]

      assert User.search("lizz", following: true, for_user: lizz) == []
    end

    test "find local and remote users for authenticated users" do
      u1 = insert(:user, %{name: "lain"})
      u2 = insert(:user, %{name: "ebn", nickname: "lain@mastodon.social", local: false})
      u3 = insert(:user, %{nickname: "lain@pleroma.soykaf.com", local: false})

      results =
        "lain"
        |> User.search(for_user: u1)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert [u1.id, u2.id, u3.id] == results
    end

    test "find only local users for unauthenticated users" do
      %{id: id} = insert(:user, %{name: "lain"})
      insert(:user, %{name: "ebn", nickname: "lain@mastodon.social", local: false})
      insert(:user, %{nickname: "lain@pleroma.soykaf.com", local: false})

      assert [%{id: ^id}] = User.search("lain")
    end

    test "find only local users for authenticated users when `limit_to_local_content` is `:all`" do
      clear_config([:instance, :limit_to_local_content], :all)

      %{id: id} = insert(:user, %{name: "lain"})
      insert(:user, %{name: "ebn", nickname: "lain@mastodon.social", local: false})
      insert(:user, %{nickname: "lain@pleroma.soykaf.com", local: false})

      assert [%{id: ^id}] = User.search("lain")
    end

    test "find all users for unauthenticated users when `limit_to_local_content` is `false`" do
      clear_config([:instance, :limit_to_local_content], false)

      u1 = insert(:user, %{name: "lain"})
      u2 = insert(:user, %{name: "ebn", nickname: "lain@mastodon.social", local: false})
      u3 = insert(:user, %{nickname: "lain@pleroma.soykaf.com", local: false})

      results =
        "lain"
        |> User.search()
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert [u1.id, u2.id, u3.id] == results
    end

    test "does not yield false-positive matches" do
      insert(:user, %{name: "John Doe"})

      Enum.each(["mary", "a", ""], fn query ->
        assert [] == User.search(query)
      end)
    end

    test "works with URIs" do
      user = insert(:user)

      results =
        User.search("http://mastodon.example.org/users/admin", resolve: true, for_user: user)

      result = results |> List.first()

      user = User.get_cached_by_ap_id("http://mastodon.example.org/users/admin")

      assert length(results) == 1

      expected =
        result
        |> Map.put(:search_rank, nil)
        |> Map.put(:search_type, nil)
        |> Map.put(:last_digest_emailed_at, nil)
        |> Map.put(:multi_factor_authentication_settings, nil)
        |> Map.put(:notification_settings, nil)

      assert user == expected
    end

    test "excludes a blocked users from search result" do
      user = insert(:user, %{nickname: "Bill"})

      [blocked_user | users] = Enum.map(0..3, &insert(:user, %{nickname: "john#{&1}"}))

      blocked_user2 =
        insert(
          :user,
          %{nickname: "john awful", ap_id: "https://awful-and-rude-instance.com/user/bully"}
        )

      User.block_domain(user, "awful-and-rude-instance.com")
      User.block(user, blocked_user)

      account_ids = User.search("john", for_user: refresh_record(user)) |> collect_ids

      assert account_ids == collect_ids(users)
      refute Enum.member?(account_ids, blocked_user.id)
      refute Enum.member?(account_ids, blocked_user2.id)
      assert length(account_ids) == 3
    end

    test "local user has the same search_rank as for users with the same nickname, but another domain" do
      user = insert(:user)
      insert(:user, nickname: "lain@mastodon.social")
      insert(:user, nickname: "lain")
      insert(:user, nickname: "lain@pleroma.social")

      assert User.search("lain@localhost", resolve: true, for_user: user)
             |> Enum.each(fn u -> u.search_rank == 0.5 end)
    end

    test "localhost is the part of the domain" do
      user = insert(:user)
      insert(:user, nickname: "another@somedomain")
      insert(:user, nickname: "lain")
      insert(:user, nickname: "lain@examplelocalhost")

      result = User.search("lain@examplelocalhost", resolve: true, for_user: user)
      assert Enum.each(result, fn u -> u.search_rank == 0.5 end)
      assert length(result) == 2
    end

    test "local user search with users" do
      user = insert(:user)
      local_user = insert(:user, nickname: "lain")
      insert(:user, nickname: "another@localhost.com")
      insert(:user, nickname: "localhost@localhost.com")

      [result] = User.search("lain@localhost", resolve: true, for_user: user)
      assert Map.put(result, :search_rank, nil) |> Map.put(:search_type, nil) == local_user
    end

    test "works with idna domains" do
      user = insert(:user, nickname: "lain@" <> to_string(:idna.encode("zetsubou.みんな")))

      results = User.search("lain@zetsubou.みんな", resolve: false, for_user: user)

      result = List.first(results)

      assert user == result |> Map.put(:search_rank, nil) |> Map.put(:search_type, nil)
    end

    test "works with idna domains converted input" do
      user = insert(:user, nickname: "lain@" <> to_string(:idna.encode("zetsubou.みんな")))

      results =
        User.search("lain@zetsubou." <> to_string(:idna.encode("zetsubou.みんな")),
          resolve: false,
          for_user: user
        )

      result = List.first(results)

      assert user == result |> Map.put(:search_rank, nil) |> Map.put(:search_type, nil)
    end

    test "works with idna domains and bad chars in domain" do
      user = insert(:user, nickname: "lain@" <> to_string(:idna.encode("zetsubou.みんな")))

      results =
        User.search("lain@zetsubou!@#$%^&*()+,-/:;<=>?[]'_{}|~`.みんな",
          resolve: false,
          for_user: user
        )

      result = List.first(results)

      assert user == result |> Map.put(:search_rank, nil) |> Map.put(:search_type, nil)
    end

    test "works with idna domains and query as link" do
      user = insert(:user, nickname: "lain@" <> to_string(:idna.encode("zetsubou.みんな")))

      results =
        User.search("https://zetsubou.みんな/users/lain",
          resolve: false,
          for_user: user
        )

      result = List.first(results)

      assert user == result |> Map.put(:search_rank, nil) |> Map.put(:search_type, nil)
    end
  end
end
