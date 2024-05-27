# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NsfwApiPolicyTest do
  use Pleroma.DataCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.Constants
  alias Pleroma.Web.ActivityPub.MRF.NsfwApiPolicy

  require Pleroma.Constants

  @policy :mrf_nsfw_api

  @sfw_url "https://kittens.co/kitty.gif"
  @nsfw_url "https://b00bies.com/nsfw.jpg"
  @timeout_url "http://time.out/i.jpg"

  setup_all do
    clear_config(@policy,
      url: "http://127.0.0.1:5000/",
      threshold: 0.7,
      mark_sensitive: true,
      unlist: false,
      reject: false
    )
  end

  setup do
    Tesla.Mock.mock(fn
      # NSFW URL
      %{method: :get, url: "http://127.0.0.1:5000/?url=#{@nsfw_url}"} ->
        %Tesla.Env{status: 200, body: ~s({"score":0.99772077798843384,"url":"#{@nsfw_url}"})}

      # SFW URL
      %{method: :get, url: "http://127.0.0.1:5000/?url=#{@sfw_url}"} ->
        %Tesla.Env{status: 200, body: ~s({"score":0.00011714912398019806,"url":"#{@sfw_url}"})}

      # Timeout URL
      %{method: :get, url: "http://127.0.0.1:5000/?url=#{@timeout_url}"} ->
        {:error, :timeout}

      # Fallback URL
      %{method: :get, url: "http://127.0.0.1:5000/?url=" <> url} ->
        body =
          ~s({"error_code":500,"error_reason":"[Errno -2] Name or service not known","url":"#{url}"})

        %Tesla.Env{status: 500, body: body}
    end)

    :ok
  end

  describe "build_request_url/1" do
    test "it works" do
      expected = "http://127.0.0.1:5000/?url=https://b00bies.com/nsfw.jpg"
      assert NsfwApiPolicy.build_request_url(@nsfw_url) == expected
    end

    test "it adds a trailing slash" do
      clear_config([@policy, :url], "http://localhost:5000")

      expected = "http://localhost:5000/?url=https://b00bies.com/nsfw.jpg"
      assert NsfwApiPolicy.build_request_url(@nsfw_url) == expected
    end

    test "it adds a trailing slash preserving the path" do
      clear_config([@policy, :url], "http://localhost:5000/nsfw_api")

      expected = "http://localhost:5000/nsfw_api/?url=https://b00bies.com/nsfw.jpg"
      assert NsfwApiPolicy.build_request_url(@nsfw_url) == expected
    end
  end

  describe "parse_url/1" do
    test "returns decoded JSON from the API server" do
      expected = %{"score" => 0.99772077798843384, "url" => @nsfw_url}
      assert NsfwApiPolicy.parse_url(@nsfw_url) == {:ok, expected}
    end

    test "warns when the API server fails" do
      expected = "[NsfwApiPolicy]: The API server failed. Skipping."
      assert capture_log(fn -> NsfwApiPolicy.parse_url(@timeout_url) end) =~ expected
    end

    test "returns {:error, _} tuple when the API server fails" do
      capture_log(fn ->
        assert {:error, _} = NsfwApiPolicy.parse_url(@timeout_url)
      end)
    end
  end

  describe "check_url_nsfw/1" do
    test "returns {:nsfw, _} tuple" do
      expected = {:nsfw, %{url: @nsfw_url, score: 0.99772077798843384, threshold: 0.7}}
      assert NsfwApiPolicy.check_url_nsfw(@nsfw_url) == expected
    end

    test "returns {:sfw, _} tuple" do
      expected = {:sfw, %{url: @sfw_url, score: 0.00011714912398019806, threshold: 0.7}}
      assert NsfwApiPolicy.check_url_nsfw(@sfw_url) == expected
    end

    test "returns {:sfw, _} on failure" do
      expected = {:sfw, %{url: @timeout_url, score: nil, threshold: 0.7}}

      capture_log(fn ->
        assert NsfwApiPolicy.check_url_nsfw(@timeout_url) == expected
      end)
    end

    test "works with map URL" do
      expected = {:nsfw, %{url: @nsfw_url, score: 0.99772077798843384, threshold: 0.7}}
      assert NsfwApiPolicy.check_url_nsfw(%{"href" => @nsfw_url}) == expected
    end
  end

  describe "check_attachment_nsfw/1" do
    test "returns {:nsfw, _} if any items are NSFW" do
      attachment = %{"url" => [%{"href" => @nsfw_url}, @nsfw_url, @sfw_url]}
      assert NsfwApiPolicy.check_attachment_nsfw(attachment) == {:nsfw, attachment}
    end

    test "returns {:sfw, _} if all items are SFW" do
      attachment = %{"url" => [%{"href" => @sfw_url}, @sfw_url, @sfw_url]}
      assert NsfwApiPolicy.check_attachment_nsfw(attachment) == {:sfw, attachment}
    end

    test "works with binary URL" do
      attachment = %{"url" => @nsfw_url}
      assert NsfwApiPolicy.check_attachment_nsfw(attachment) == {:nsfw, attachment}
    end
  end

  describe "check_object_nsfw/1" do
    test "returns {:nsfw, _} if any items are NSFW" do
      object = %{"attachment" => [%{"url" => [%{"href" => @nsfw_url}, @sfw_url]}]}
      assert NsfwApiPolicy.check_object_nsfw(object) == {:nsfw, object}
    end

    test "returns {:sfw, _} if all items are SFW" do
      object = %{"attachment" => [%{"url" => [%{"href" => @sfw_url}, @sfw_url]}]}
      assert NsfwApiPolicy.check_object_nsfw(object) == {:sfw, object}
    end

    test "works with embedded object" do
      object = %{"object" => %{"attachment" => [%{"url" => [%{"href" => @nsfw_url}, @sfw_url]}]}}
      assert NsfwApiPolicy.check_object_nsfw(object) == {:nsfw, object}
    end
  end

  describe "unlist/1" do
    test "unlist addressing" do
      user = insert(:user)

      object = %{
        "to" => [Constants.as_public()],
        "cc" => [user.follower_address, "https://hello.world/users/alex"],
        "actor" => user.ap_id
      }

      expected = %{
        "to" => [user.follower_address],
        "cc" => [Constants.as_public(), "https://hello.world/users/alex"],
        "actor" => user.ap_id
      }

      assert NsfwApiPolicy.unlist(object) == expected
    end

    test "raise if user isn't found" do
      object = %{
        "to" => [Constants.as_public()],
        "cc" => [],
        "actor" => "https://hello.world/users/alex"
      }

      assert_raise(RuntimeError, fn ->
        NsfwApiPolicy.unlist(object)
      end)
    end
  end

  describe "mark_sensitive/1" do
    test "adds nsfw tag and marks sensitive" do
      object = %{"tag" => ["yolo"]}
      expected = %{"tag" => ["yolo", "nsfw"], "sensitive" => true}
      assert NsfwApiPolicy.mark_sensitive(object) == expected
    end

    test "works with embedded object" do
      object = %{"object" => %{"tag" => ["yolo"]}}
      expected = %{"object" => %{"tag" => ["yolo", "nsfw"], "sensitive" => true}}
      assert NsfwApiPolicy.mark_sensitive(object) == expected
    end
  end

  describe "filter/1" do
    setup do
      user = insert(:user)

      nsfw_object = %{
        "to" => [Constants.as_public()],
        "cc" => [user.follower_address],
        "actor" => user.ap_id,
        "attachment" => [%{"url" => @nsfw_url}]
      }

      sfw_object = %{
        "to" => [Constants.as_public()],
        "cc" => [user.follower_address],
        "actor" => user.ap_id,
        "attachment" => [%{"url" => @sfw_url}]
      }

      %{user: user, nsfw_object: nsfw_object, sfw_object: sfw_object}
    end

    test "passes SFW object through", %{sfw_object: object} do
      {:ok, _} = NsfwApiPolicy.filter(object)
    end

    test "passes NSFW object through when actions are disabled", %{nsfw_object: object} do
      clear_config([@policy, :mark_sensitive], false)
      clear_config([@policy, :unlist], false)
      clear_config([@policy, :reject], false)
      {:ok, _} = NsfwApiPolicy.filter(object)
    end

    test "passes NSFW object through when :threshold is 1", %{nsfw_object: object} do
      clear_config([@policy, :reject], true)
      clear_config([@policy, :threshold], 1)
      {:ok, _} = NsfwApiPolicy.filter(object)
    end

    test "rejects SFW object through when :threshold is 0", %{sfw_object: object} do
      clear_config([@policy, :reject], true)
      clear_config([@policy, :threshold], 0)
      {:reject, _} = NsfwApiPolicy.filter(object)
    end

    test "rejects NSFW when :reject is enabled", %{nsfw_object: object} do
      clear_config([@policy, :reject], true)
      {:reject, _} = NsfwApiPolicy.filter(object)
    end

    test "passes NSFW through when :reject is disabled", %{nsfw_object: object} do
      clear_config([@policy, :reject], false)
      {:ok, _} = NsfwApiPolicy.filter(object)
    end

    test "unlists NSFW when :unlist is enabled", %{user: user, nsfw_object: object} do
      clear_config([@policy, :unlist], true)
      {:ok, object} = NsfwApiPolicy.filter(object)
      assert object["to"] == [user.follower_address]
    end

    test "passes NSFW through when :unlist is disabled", %{nsfw_object: object} do
      clear_config([@policy, :unlist], false)
      {:ok, object} = NsfwApiPolicy.filter(object)
      assert object["to"] == [Constants.as_public()]
    end
  end
end
