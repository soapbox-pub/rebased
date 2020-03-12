# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFingerTest do
  use Pleroma.DataCase
  alias Pleroma.Web.WebFinger
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "host meta" do
    test "returns a link to the xml lrdd" do
      host_info = WebFinger.host_meta()

      assert String.contains?(host_info, Pleroma.Web.base_url())
    end
  end

  describe "incoming webfinger request" do
    test "works for fqns" do
      user = insert(:user)

      {:ok, result} =
        WebFinger.webfinger("#{user.nickname}@#{Pleroma.Web.Endpoint.host()}", "XML")

      assert is_binary(result)
    end

    test "works for ap_ids" do
      user = insert(:user)

      {:ok, result} = WebFinger.webfinger(user.ap_id, "XML")
      assert is_binary(result)
    end
  end

  describe "fingering" do
    test "returns error when fails parse xml or json" do
      user = "invalid_content@social.heldscal.la"
      assert {:error, %Jason.DecodeError{}} = WebFinger.finger(user)
    end

    test "returns the ActivityPub actor URI for an ActivityPub user" do
      user = "framasoft@framatube.org"

      {:ok, _data} = WebFinger.finger(user)
    end

    test "returns the ActivityPub actor URI for an ActivityPub user with the ld+json mimetype" do
      user = "kaniini@gerzilla.de"

      {:ok, data} = WebFinger.finger(user)

      assert data["ap_id"] == "https://gerzilla.de/channel/kaniini"
    end

    test "it work for AP-only user" do
      user = "kpherox@mstdn.jp"

      {:ok, data} = WebFinger.finger(user)

      assert data["magic_key"] == nil
      assert data["salmon"] == nil

      assert data["topic"] == "https://mstdn.jp/users/kPherox.atom"
      assert data["subject"] == "acct:kPherox@mstdn.jp"
      assert data["ap_id"] == "https://mstdn.jp/users/kPherox"
      assert data["subscribe_address"] == "https://mstdn.jp/authorize_interaction?acct={uri}"
    end

    test "it works for friendica" do
      user = "lain@squeet.me"

      {:ok, _data} = WebFinger.finger(user)
    end

    test "it gets the xrd endpoint" do
      {:ok, template} = WebFinger.find_lrdd_template("social.heldscal.la")

      assert template == "https://social.heldscal.la/.well-known/webfinger?resource={uri}"
    end

    test "it gets the xrd endpoint for hubzilla" do
      {:ok, template} = WebFinger.find_lrdd_template("macgirvin.com")

      assert template == "https://macgirvin.com/xrd/?uri={uri}"
    end

    test "it gets the xrd endpoint for statusnet" do
      {:ok, template} = WebFinger.find_lrdd_template("status.alpicola.com")

      assert template == "http://status.alpicola.com/main/xrd?uri={uri}"
    end

    test "it works with idna domains as nickname" do
      nickname = "lain@" <> to_string(:idna.encode("zetsubou.みんな"))

      {:ok, _data} = WebFinger.finger(nickname)
    end

    test "it works with idna domains as link" do
      ap_id = "https://" <> to_string(:idna.encode("zetsubou.みんな")) <> "/users/lain"
      {:ok, _data} = WebFinger.finger(ap_id)
    end
  end
end
