# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.TwitterAPITest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "it registers a new user and returns the user." do
    data = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :password => "bear",
      :confirm => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)

    assert user == User.get_cached_by_nickname("lain")
  end

  test "it registers a new user with empty string in bio and returns the user" do
    data = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :bio => "",
      :password => "bear",
      :confirm => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)

    assert user == User.get_cached_by_nickname("lain")
  end

  test "it sends confirmation email if :account_activation_required is specified in instance config" do
    clear_config([:instance, :account_activation_required], true)

    data = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :bio => "",
      :password => "bear",
      :confirm => "bear"
    }

    {:ok, user} = TwitterAPI.register_user(data)
    ObanHelpers.perform_all()

    refute user.is_confirmed

    email = Pleroma.Emails.UserEmail.account_confirmation_email(user)

    notify_email = Pleroma.Config.get([:instance, :notify_email])
    instance_name = Pleroma.Config.get([:instance, :name])

    Swoosh.TestAssertions.assert_email_sent(
      from: {instance_name, notify_email},
      to: {user.name, user.email},
      html_body: email.html_body
    )
  end

  test "it sends an admin email if :account_approval_required is specified in instance config" do
    clear_config([:instance, :account_approval_required], true)

    admin = insert(:user, is_admin: true)

    data = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :bio => "",
      :password => "bear",
      :confirm => "bear",
      :reason => "I love anime"
    }

    {:ok, user} = TwitterAPI.register_user(data)
    ObanHelpers.perform_all()

    refute user.is_approved

    user_email = Pleroma.Emails.UserEmail.approval_pending_email(user)
    admin_email = Pleroma.Emails.AdminEmail.new_unapproved_registration(admin, user)

    notify_email = Pleroma.Config.get([:instance, :notify_email])
    instance_name = Pleroma.Config.get([:instance, :name])

    # User approval email
    Swoosh.TestAssertions.assert_email_sent(
      from: {instance_name, notify_email},
      to: {user.name, user.email},
      html_body: user_email.html_body
    )

    # Admin email
    Swoosh.TestAssertions.assert_email_sent(
      from: {instance_name, notify_email},
      to: {admin.name, admin.email},
      html_body: admin_email.html_body
    )
  end

  test "it registers a new user and parses mentions in the bio" do
    data1 = %{
      :username => "john",
      :email => "john@gmail.com",
      :fullname => "John Doe",
      :bio => "test",
      :password => "bear",
      :confirm => "bear"
    }

    {:ok, user1} = TwitterAPI.register_user(data1)

    data2 = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :bio => "@john test",
      :password => "bear",
      :confirm => "bear"
    }

    {:ok, user2} = TwitterAPI.register_user(data2)

    expected_text =
      ~s(<span class="h-card"><a class="u-url mention" data-user="#{user1.id}" href="#{user1.ap_id}" rel="ugc">@<span>john</span></a></span> test)

    assert user2.bio == expected_text
  end

  describe "register with one time token" do
    setup do: clear_config([:instance, :registrations_open], false)

    test "returns user on success" do
      {:ok, invite} = UserInviteToken.create_invite()

      data = %{
        :username => "vinny",
        :email => "pasta@pizza.vs",
        :fullname => "Vinny Vinesauce",
        :bio => "streamer",
        :password => "hiptofbees",
        :confirm => "hiptofbees",
        :token => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)

      assert user == User.get_cached_by_nickname("vinny")

      invite = Repo.get_by(UserInviteToken, token: invite.token)
      assert invite.used == true
    end

    test "returns error on invalid token" do
      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => "DudeLetMeInImAFairy"
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Invalid token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on expired token" do
      {:ok, invite} = UserInviteToken.create_invite()
      UserInviteToken.update_invite!(invite, used: true)

      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  describe "registers with date limited token" do
    setup do: clear_config([:instance, :registrations_open], false)

    setup do
      data = %{
        :username => "vinny",
        :email => "pasta@pizza.vs",
        :fullname => "Vinny Vinesauce",
        :bio => "streamer",
        :password => "hiptofbees",
        :confirm => "hiptofbees"
      }

      check_fn = fn invite ->
        data = Map.put(data, :token, invite.token)
        {:ok, user} = TwitterAPI.register_user(data)

        assert user == User.get_cached_by_nickname("vinny")
      end

      {:ok, data: data, check_fn: check_fn}
    end

    test "returns user on success", %{check_fn: check_fn} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today()})

      check_fn.(invite)

      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end

    test "returns user on token which expired tomorrow", %{check_fn: check_fn} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), 1)})

      check_fn.(invite)

      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end

    test "returns an error on overdue date", %{data: data} do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1)})

      data = Map.put(data, "token", invite.token)

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("vinny")
      invite = Repo.get_by(UserInviteToken, token: invite.token)

      refute invite.used
    end
  end

  describe "registers with reusable token" do
    setup do: clear_config([:instance, :registrations_open], false)

    test "returns user on success, after him registration fails" do
      {:ok, invite} = UserInviteToken.create_invite(%{max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 99)

      data = %{
        :username => "vinny",
        :email => "pasta@pizza.vs",
        :fullname => "Vinny Vinesauce",
        :bio => "streamer",
        :password => "hiptofbees",
        :confirm => "hiptofbees",
        :token => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      assert user == User.get_cached_by_nickname("vinny")

      invite = Repo.get_by(UserInviteToken, token: invite.token)
      assert invite.used == true

      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  describe "registers with reusable date limited token" do
    setup do: clear_config([:instance, :registrations_open], false)

    test "returns user on success" do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today(), max_use: 100})

      data = %{
        :username => "vinny",
        :email => "pasta@pizza.vs",
        :fullname => "Vinny Vinesauce",
        :bio => "streamer",
        :password => "hiptofbees",
        :confirm => "hiptofbees",
        :token => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      assert user == User.get_cached_by_nickname("vinny")

      invite = Repo.get_by(UserInviteToken, token: invite.token)
      refute invite.used
    end

    test "error after max uses" do
      {:ok, invite} = UserInviteToken.create_invite(%{expires_at: Date.utc_today(), max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 99)

      data = %{
        :username => "vinny",
        :email => "pasta@pizza.vs",
        :fullname => "Vinny Vinesauce",
        :bio => "streamer",
        :password => "hiptofbees",
        :confirm => "hiptofbees",
        :token => invite.token
      }

      {:ok, user} = TwitterAPI.register_user(data)
      assert user == User.get_cached_by_nickname("vinny")

      invite = Repo.get_by(UserInviteToken, token: invite.token)
      assert invite.used == true

      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on overdue date" do
      {:ok, invite} =
        UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1), max_use: 100})

      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end

    test "returns error on with overdue date and after max" do
      {:ok, invite} =
        UserInviteToken.create_invite(%{expires_at: Date.add(Date.utc_today(), -1), max_use: 100})

      UserInviteToken.update_invite!(invite, uses: 100)

      data = %{
        :username => "GrimReaper",
        :email => "death@reapers.afterlife",
        :fullname => "Reaper Grim",
        :bio => "Your time has come",
        :password => "scythe",
        :confirm => "scythe",
        :token => invite.token
      }

      {:error, msg} = TwitterAPI.register_user(data)

      assert msg == "Expired token"
      refute User.get_cached_by_nickname("GrimReaper")
    end
  end

  test "it returns the error on registration problems" do
    data = %{
      :username => "lain",
      :email => "lain@wired.jp",
      :fullname => "lain iwakura",
      :bio => "close the world."
    }

    {:error, error} = TwitterAPI.register_user(data)

    assert is_binary(error)
    refute User.get_cached_by_nickname("lain")
  end
end
