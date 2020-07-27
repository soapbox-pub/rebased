# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.PipelineTest do
  use Pleroma.DataCase

  import Mock
  import Pleroma.Factory

  describe "common_pipeline/2" do
    setup do
      clear_config([:instance, :federating], true)
      :ok
    end

    test "when given an `object_data` in meta, Federation will receive a the original activity with the `object` field set to this embedded object" do
      activity = insert(:note_activity)
      object = %{"id" => "1", "type" => "Love"}
      meta = [local: true, object_data: object]

      activity_with_object = %{activity | data: Map.put(activity.data, "object", object)}

      with_mocks([
        {Pleroma.Web.ActivityPub.ObjectValidator, [], [validate: fn o, m -> {:ok, o, m} end]},
        {
          Pleroma.Web.ActivityPub.MRF,
          [],
          [filter: fn o -> {:ok, o} end]
        },
        {
          Pleroma.Web.ActivityPub.ActivityPub,
          [],
          [persist: fn o, m -> {:ok, o, m} end]
        },
        {
          Pleroma.Web.ActivityPub.SideEffects,
          [],
          [
            handle: fn o, m -> {:ok, o, m} end,
            handle_after_transaction: fn m -> m end
          ]
        },
        {
          Pleroma.Web.Federator,
          [],
          [publish: fn _o -> :ok end]
        }
      ]) do
        assert {:ok, ^activity, ^meta} =
                 Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity, meta)

        assert_called(Pleroma.Web.ActivityPub.ObjectValidator.validate(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.MRF.filter(activity))
        assert_called(Pleroma.Web.ActivityPub.ActivityPub.persist(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.SideEffects.handle(activity, meta))
        refute called(Pleroma.Web.Federator.publish(activity))
        assert_called(Pleroma.Web.Federator.publish(activity_with_object))
      end
    end

    test "it goes through validation, filtering, persisting, side effects and federation for local activities" do
      activity = insert(:note_activity)
      meta = [local: true]

      with_mocks([
        {Pleroma.Web.ActivityPub.ObjectValidator, [], [validate: fn o, m -> {:ok, o, m} end]},
        {
          Pleroma.Web.ActivityPub.MRF,
          [],
          [filter: fn o -> {:ok, o} end]
        },
        {
          Pleroma.Web.ActivityPub.ActivityPub,
          [],
          [persist: fn o, m -> {:ok, o, m} end]
        },
        {
          Pleroma.Web.ActivityPub.SideEffects,
          [],
          [
            handle: fn o, m -> {:ok, o, m} end,
            handle_after_transaction: fn m -> m end
          ]
        },
        {
          Pleroma.Web.Federator,
          [],
          [publish: fn _o -> :ok end]
        }
      ]) do
        assert {:ok, ^activity, ^meta} =
                 Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity, meta)

        assert_called(Pleroma.Web.ActivityPub.ObjectValidator.validate(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.MRF.filter(activity))
        assert_called(Pleroma.Web.ActivityPub.ActivityPub.persist(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.SideEffects.handle(activity, meta))
        assert_called(Pleroma.Web.Federator.publish(activity))
      end
    end

    test "it goes through validation, filtering, persisting, side effects without federation for remote activities" do
      activity = insert(:note_activity)
      meta = [local: false]

      with_mocks([
        {Pleroma.Web.ActivityPub.ObjectValidator, [], [validate: fn o, m -> {:ok, o, m} end]},
        {
          Pleroma.Web.ActivityPub.MRF,
          [],
          [filter: fn o -> {:ok, o} end]
        },
        {
          Pleroma.Web.ActivityPub.ActivityPub,
          [],
          [persist: fn o, m -> {:ok, o, m} end]
        },
        {
          Pleroma.Web.ActivityPub.SideEffects,
          [],
          [handle: fn o, m -> {:ok, o, m} end, handle_after_transaction: fn m -> m end]
        },
        {
          Pleroma.Web.Federator,
          [],
          []
        }
      ]) do
        assert {:ok, ^activity, ^meta} =
                 Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity, meta)

        assert_called(Pleroma.Web.ActivityPub.ObjectValidator.validate(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.MRF.filter(activity))
        assert_called(Pleroma.Web.ActivityPub.ActivityPub.persist(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.SideEffects.handle(activity, meta))
      end
    end

    test "it goes through validation, filtering, persisting, side effects without federation for local activities if federation is deactivated" do
      clear_config([:instance, :federating], false)

      activity = insert(:note_activity)
      meta = [local: true]

      with_mocks([
        {Pleroma.Web.ActivityPub.ObjectValidator, [], [validate: fn o, m -> {:ok, o, m} end]},
        {
          Pleroma.Web.ActivityPub.MRF,
          [],
          [filter: fn o -> {:ok, o} end]
        },
        {
          Pleroma.Web.ActivityPub.ActivityPub,
          [],
          [persist: fn o, m -> {:ok, o, m} end]
        },
        {
          Pleroma.Web.ActivityPub.SideEffects,
          [],
          [handle: fn o, m -> {:ok, o, m} end, handle_after_transaction: fn m -> m end]
        },
        {
          Pleroma.Web.Federator,
          [],
          []
        }
      ]) do
        assert {:ok, ^activity, ^meta} =
                 Pleroma.Web.ActivityPub.Pipeline.common_pipeline(activity, meta)

        assert_called(Pleroma.Web.ActivityPub.ObjectValidator.validate(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.MRF.filter(activity))
        assert_called(Pleroma.Web.ActivityPub.ActivityPub.persist(activity, meta))
        assert_called(Pleroma.Web.ActivityPub.SideEffects.handle(activity, meta))
      end
    end
  end
end
