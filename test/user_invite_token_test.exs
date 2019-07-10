# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserInviteTokenTest do
  use ExUnit.Case, async: true
  use Pleroma.DataCase
  alias Pleroma.UserInviteToken

  describe "valid_invite?/1 one time invites" do
    setup do
      invite = %UserInviteToken{invite_type: "one_time"}

      {:ok, invite: invite}
    end

    test "not used returns true", %{invite: invite} do
      invite = %{invite | used: false}
      assert UserInviteToken.valid_invite?(invite)
    end

    test "used  returns false", %{invite: invite} do
      invite = %{invite | used: true}
      refute UserInviteToken.valid_invite?(invite)
    end
  end

  describe "valid_invite?/1 reusable invites" do
    setup do
      invite = %UserInviteToken{
        invite_type: "reusable",
        max_use: 5
      }

      {:ok, invite: invite}
    end

    test "with less uses then max use returns true", %{invite: invite} do
      invite = %{invite | uses: 4}
      assert UserInviteToken.valid_invite?(invite)
    end

    test "with equal or more uses then max use returns false", %{invite: invite} do
      invite = %{invite | uses: 5}

      refute UserInviteToken.valid_invite?(invite)

      invite = %{invite | uses: 6}

      refute UserInviteToken.valid_invite?(invite)
    end
  end

  describe "valid_token?/1 date limited invites" do
    setup do
      invite = %UserInviteToken{invite_type: "date_limited"}
      {:ok, invite: invite}
    end

    test "expires today returns true", %{invite: invite} do
      invite = %{invite | expires_at: Date.utc_today()}
      assert UserInviteToken.valid_invite?(invite)
    end

    test "expires yesterday returns false", %{invite: invite} do
      invite = %{invite | expires_at: Date.add(Date.utc_today(), -1)}
      invite = Repo.insert!(invite)
      refute UserInviteToken.valid_invite?(invite)
    end
  end

  describe "valid_token?/1 reusable date limited invites" do
    setup do
      invite = %UserInviteToken{invite_type: "reusable_date_limited", max_use: 5}
      {:ok, invite: invite}
    end

    test "not overdue date and less uses returns true", %{invite: invite} do
      invite = %{invite | expires_at: Date.utc_today(), uses: 4}
      assert UserInviteToken.valid_invite?(invite)
    end

    test "overdue date and less uses returns false", %{invite: invite} do
      invite = %{invite | expires_at: Date.add(Date.utc_today(), -1)}
      invite = Repo.insert!(invite)
      refute UserInviteToken.valid_invite?(invite)
    end

    test "not overdue date with more uses returns false", %{invite: invite} do
      invite = %{invite | expires_at: Date.utc_today(), uses: 5}
      refute UserInviteToken.valid_invite?(invite)
    end

    test "overdue date with more uses returns false", %{invite: invite} do
      invite = %{invite | expires_at: Date.add(Date.utc_today(), -1), uses: 5}
      invite = Repo.insert!(invite)
      refute UserInviteToken.valid_invite?(invite)
    end
  end
end
