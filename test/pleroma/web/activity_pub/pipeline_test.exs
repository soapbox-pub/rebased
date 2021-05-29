# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.PipelineTest do
  use Pleroma.DataCase, async: true

  import Mox
  import Pleroma.Factory

  alias Pleroma.ConfigMock
  alias Pleroma.Web.ActivityPub.ActivityPubMock
  alias Pleroma.Web.ActivityPub.MRFMock
  alias Pleroma.Web.ActivityPub.ObjectValidatorMock
  alias Pleroma.Web.ActivityPub.SideEffectsMock
  alias Pleroma.Web.FederatorMock

  setup :verify_on_exit!

  describe "common_pipeline/2" do
    setup do
      ObjectValidatorMock
      |> expect(:validate, fn o, m -> {:ok, o, m} end)

      MRFMock
      |> expect(:pipeline_filter, fn o, m -> {:ok, o, m} end)

      SideEffectsMock
      |> expect(:handle, fn o, m -> {:ok, o, m} end)
      |> expect(:handle_after_transaction, fn m -> m end)

      :ok
    end

    test "when given an `object_data` in meta, Federation will receive a the original activity with the `object` field set to this embedded object" do
      activity = insert(:note_activity)
      object = %{"id" => "1", "type" => "Love"}
      meta = [local: true, object_data: object]

      activity_with_object = %{activity | data: Map.put(activity.data, "object", object)}

      ActivityPubMock
      |> expect(:persist, fn _, m -> {:ok, activity, m} end)

      FederatorMock
      |> expect(:publish, fn ^activity_with_object -> :ok end)

      ConfigMock
      |> expect(:get, fn [:instance, :federating] -> true end)

      assert {:ok, ^activity, ^meta} =
               Pleroma.Web.ActivityPub.Pipeline.common_pipeline(
                 activity.data,
                 meta
               )
    end

    test "it goes through validation, filtering, persisting, side effects and federation for local activities" do
      activity = insert(:note_activity)
      meta = [local: true]

      ActivityPubMock
      |> expect(:persist, fn _, m -> {:ok, activity, m} end)

      FederatorMock
      |> expect(:publish, fn ^activity -> :ok end)

      ConfigMock
      |> expect(:get, fn [:instance, :federating] -> true end)

      assert {:ok, ^activity, ^meta} =
               Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity.data, meta)
    end

    test "it goes through validation, filtering, persisting, side effects without federation for remote activities" do
      activity = insert(:note_activity)
      meta = [local: false]

      ActivityPubMock
      |> expect(:persist, fn _, m -> {:ok, activity, m} end)

      ConfigMock
      |> expect(:get, fn [:instance, :federating] -> true end)

      assert {:ok, ^activity, ^meta} =
               Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity.data, meta)
    end

    test "it goes through validation, filtering, persisting, side effects without federation for local activities if federation is deactivated" do
      activity = insert(:note_activity)
      meta = [local: true]

      ActivityPubMock
      |> expect(:persist, fn _, m -> {:ok, activity, m} end)

      ConfigMock
      |> expect(:get, fn [:instance, :federating] -> false end)

      assert {:ok, ^activity, ^meta} =
               Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity.data, meta)
    end
  end
end
