# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mock
  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.Federator
  alias Pleroma.Workers.ReceiverWorker

  test "it does not retry MRF reject" do
    params = insert(:note).data

    with_mock Pleroma.Web.ActivityPub.Transmogrifier,
      handle_incoming: fn _ -> {:reject, "MRF"} end do
      assert {:cancel, {:reject, "MRF"}} =
               ReceiverWorker.perform(%Oban.Job{
                 args: %{"op" => "incoming_ap_doc", "params" => params}
               })
    end
  end

  test "it does not retry ObjectValidator reject" do
    params =
      insert(:note_activity).data
      |> Map.put("id", Pleroma.Web.ActivityPub.Utils.generate_activity_id())
      |> Map.put("object", %{
        "type" => "Note",
        "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id()
      })

    with_mock Pleroma.Web.ActivityPub.ObjectValidator, [:passthrough],
      validate: fn _, _ -> {:error, %Ecto.Changeset{}} end do
      assert {:cancel, {:error, %Ecto.Changeset{}}} =
               ReceiverWorker.perform(%Oban.Job{
                 args: %{"op" => "incoming_ap_doc", "params" => params}
               })
    end
  end

  test "it does not retry duplicates" do
    params = insert(:note_activity).data

    assert {:cancel, :already_present} =
             ReceiverWorker.perform(%Oban.Job{
               args: %{"op" => "incoming_ap_doc", "params" => params}
             })
  end

  describe "cancels on a failed user fetch" do
    setup do
      Tesla.Mock.mock(fn
        %{url: "https://springfield.social/users/bart"} ->
          %Tesla.Env{
            status: 403,
            body: ""
          }

        %{url: "https://springfield.social/users/troymcclure"} ->
          %Tesla.Env{
            status: 404,
            body: ""
          }

        %{url: "https://springfield.social/users/hankscorpio"} ->
          %Tesla.Env{
            status: 410,
            body: ""
          }
      end)
    end

    test "when request returns a 403" do
      params =
        insert(:note_activity).data
        |> Map.put("actor", "https://springfield.social/users/bart")

      {:ok, oban_job} =
        Federator.incoming_ap_doc(%{
          method: "POST",
          req_headers: [],
          request_path: "/inbox",
          params: params,
          query_string: ""
        })

      assert {:cancel, {:error, :forbidden}} = ReceiverWorker.perform(oban_job)
    end

    test "when request returns a 404" do
      params =
        insert(:note_activity).data
        |> Map.put("actor", "https://springfield.social/users/troymcclure")

      {:ok, oban_job} =
        Federator.incoming_ap_doc(%{
          method: "POST",
          req_headers: [],
          request_path: "/inbox",
          params: params,
          query_string: ""
        })

      assert {:cancel, {:error, :not_found}} = ReceiverWorker.perform(oban_job)
    end

    test "when request returns a 410" do
      params =
        insert(:note_activity).data
        |> Map.put("actor", "https://springfield.social/users/hankscorpio")

      {:ok, oban_job} =
        Federator.incoming_ap_doc(%{
          method: "POST",
          req_headers: [],
          request_path: "/inbox",
          params: params,
          query_string: ""
        })

      assert {:cancel, {:error, :not_found}} = ReceiverWorker.perform(oban_job)
    end

    test "when user account is disabled" do
      user = insert(:user)

      fake_activity = URI.parse(user.ap_id) |> Map.put(:path, "/fake-activity") |> to_string

      params =
        insert(:note_activity, user: user).data
        |> Map.put("id", fake_activity)

      {:ok, %User{}} = User.set_activation(user, false)

      {:ok, oban_job} =
        Federator.incoming_ap_doc(%{
          method: "POST",
          req_headers: [],
          request_path: "/inbox",
          params: params,
          query_string: ""
        })

      assert {:cancel, {:user_active, false}} = ReceiverWorker.perform(oban_job)
    end
  end

  test "it can validate the signature" do
    Tesla.Mock.mock(fn
      %{url: "https://phpc.social/users/denniskoch"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/denniskoch.json"),
          headers: [{"content-type", "application/activity+json"}]
        }

      %{url: "https://phpc.social/users/denniskoch/collections/featured"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body:
            File.read!("test/fixtures/users_mock/masto_featured.json")
            |> String.replace("{{domain}}", "phpc.social")
            |> String.replace("{{nickname}}", "denniskoch")
        }
    end)

    params =
      File.read!("test/fixtures/receiver_worker_signature_activity.json") |> Jason.decode!()

    req_headers = [
      ["accept-encoding", "gzip"],
      ["content-length", "5184"],
      ["content-type", "application/activity+json"],
      ["date", "Thu, 25 Jul 2024 13:33:31 GMT"],
      ["digest", "SHA-256=ouge/6HP2/QryG6F3JNtZ6vzs/hSwMk67xdxe87eH7A="],
      ["host", "bikeshed.party"],
      [
        "signature",
        "keyId=\"https://mastodon.social/users/bastianallgeier#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date digest content-type\",signature=\"ymE3vn5Iw50N6ukSp8oIuXJB5SBjGAGjBasdTDvn+ahZIzq2SIJfmVCsIIzyqIROnhWyQoTbavTclVojEqdaeOx+Ejz2wBnRBmhz5oemJLk4RnnCH0lwMWyzeY98YAvxi9Rq57Gojuv/1lBqyGa+rDzynyJpAMyFk17XIZpjMKuTNMCbjMDy76ILHqArykAIL/v1zxkgwxY/+ELzxqMpNqtZ+kQ29znNMUBB3eVZ/mNAHAz6o33Y9VKxM2jw+08vtuIZOusXyiHbRiaj2g5HtN2WBUw1MzzfRfHF2/yy7rcipobeoyk5RvP5SyHV3WrIeZ3iyoNfmv33y8fxllF0EA==\""
      ],
      [
        "user-agent",
        "http.rb/5.2.0 (Mastodon/4.3.0-nightly.2024-07-25; +https://mastodon.social/)"
      ]
    ]

    {:ok, oban_job} =
      Federator.incoming_ap_doc(%{
        method: "POST",
        req_headers: req_headers,
        request_path: "/inbox",
        params: params,
        query_string: ""
      })

    assert {:ok, %Pleroma.Activity{}} = ReceiverWorker.perform(oban_job)
  end

  test "cancels due to origin containment" do
    params =
      insert(:note_activity).data
      |> Map.put("id", "https://notorigindomain.com/activity")

    {:ok, oban_job} =
      Federator.incoming_ap_doc(%{
        method: "POST",
        req_headers: [],
        request_path: "/inbox",
        params: params,
        query_string: ""
      })

    assert {:cancel, :origin_containment_failed} = ReceiverWorker.perform(oban_job)
  end

  test "canceled due to deleted object" do
    params =
      insert(:announce_activity).data
      |> Map.put("object", "http://localhost:4001/deleted")

    Tesla.Mock.mock(fn
      %{url: "http://localhost:4001/deleted"} ->
        %Tesla.Env{
          status: 404,
          body: ""
        }
    end)

    {:ok, oban_job} =
      Federator.incoming_ap_doc(%{
        method: "POST",
        req_headers: [],
        request_path: "/inbox",
        params: params,
        query_string: ""
      })

    assert {:cancel, _} = ReceiverWorker.perform(oban_job)
  end
end
