# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Instances
  alias Pleroma.Workers.RemoteFetcherWorker

  @deleted_object_one "https://deleted-404.example.com/"
  @deleted_object_two "https://deleted-410.example.com/"
  @unauthorized_object "https://unauthorized.example.com/"
  @unreachable_object "https://unreachable.example.com/"
  @depth_object "https://depth.example.com/"

  describe "it does not" do
    setup do
      Tesla.Mock.mock(fn
        %{method: :get, url: @deleted_object_one} ->
          %Tesla.Env{
            status: 404
          }

        %{method: :get, url: @deleted_object_two} ->
          %Tesla.Env{
            status: 410
          }

        %{method: :get, url: @unauthorized_object} ->
          %Tesla.Env{
            status: 403
          }

        %{method: :get, url: @depth_object} ->
          %Tesla.Env{
            status: 200
          }
      end)
    end

    test "requeue a deleted object" do
      assert {:cancel, _} =
               RemoteFetcherWorker.perform(%Oban.Job{
                 args: %{"op" => "fetch_remote", "id" => @deleted_object_one}
               })

      assert {:cancel, _} =
               RemoteFetcherWorker.perform(%Oban.Job{
                 args: %{"op" => "fetch_remote", "id" => @deleted_object_two}
               })
    end

    test "requeue an unauthorized object" do
      assert {:cancel, _} =
               RemoteFetcherWorker.perform(%Oban.Job{
                 args: %{"op" => "fetch_remote", "id" => @unauthorized_object}
               })
    end

    test "fetch an unreachable instance" do
      Instances.set_consistently_unreachable(@unreachable_object)

      refute Instances.reachable?(@unreachable_object)

      assert {:cancel, _} =
               RemoteFetcherWorker.perform(%Oban.Job{
                 args: %{"op" => "fetch_remote", "id" => @unreachable_object}
               })
    end

    test "requeue an object that exceeded depth" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:cancel, _} =
               RemoteFetcherWorker.perform(%Oban.Job{
                 args: %{"op" => "fetch_remote", "id" => @depth_object, "depth" => 1}
               })
    end
  end
end
