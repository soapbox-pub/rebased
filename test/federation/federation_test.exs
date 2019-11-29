# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Integration.FederationTest do
  use Pleroma.DataCase
  @moduletag :federated
  import Pleroma.Cluster

  setup_all do
    Pleroma.Cluster.spawn_default_cluster()
    :ok
  end

  @federated1 :"federated1@127.0.0.1"
  describe "federated cluster primitives" do
    test "within/2 captures local bindings and executes block on remote node" do
      captured_binding = :captured

      result =
        within @federated1 do
          user = Pleroma.Factory.insert(:user)
          {captured_binding, node(), user}
        end

      assert {:captured, @federated1, user} = result
      refute Pleroma.User.get_by_id(user.id)
      assert user.id == within(@federated1, do: Pleroma.User.get_by_id(user.id)).id
    end

    test "runs webserver on customized port" do
      {nickname, url, url_404} =
        within @federated1 do
          import Pleroma.Web.Router.Helpers
          user = Pleroma.Factory.insert(:user)
          user_url = account_url(Pleroma.Web.Endpoint, :show, user)
          url_404 = account_url(Pleroma.Web.Endpoint, :show, "not-exists")

          {user.nickname, user_url, url_404}
        end

      assert {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(~c"#{url}")
      assert %{"acct" => ^nickname} = Jason.decode!(body)
      assert {:ok, {{_, 404, _}, _headers, _body}} = :httpc.request(~c"#{url_404}")
    end
  end
end
