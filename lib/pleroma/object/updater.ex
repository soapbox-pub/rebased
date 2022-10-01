# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.Updater do
  require Pleroma.Constants

  def update_content_fields(orig_object_data, updated_object) do
    Pleroma.Constants.status_updatable_fields()
    |> Enum.reduce(
      %{data: orig_object_data, updated: false},
      fn field, %{data: data, updated: updated} ->
        updated =
          updated or
            (field != "updated" and
               Map.get(updated_object, field) != Map.get(orig_object_data, field))

        data =
          if Map.has_key?(updated_object, field) do
            Map.put(data, field, updated_object[field])
          else
            Map.drop(data, [field])
          end

        %{data: data, updated: updated}
      end
    )
  end

  def maybe_history(object) do
    with history <- Map.get(object, "formerRepresentations"),
         true <- is_map(history),
         "OrderedCollection" <- Map.get(history, "type"),
         true <- is_list(Map.get(history, "orderedItems")),
         true <- is_integer(Map.get(history, "totalItems")) do
      history
    else
      _ -> nil
    end
  end

  def history_for(object) do
    with history when not is_nil(history) <- maybe_history(object) do
      history
    else
      _ -> history_skeleton()
    end
  end

  defp history_skeleton do
    %{
      "type" => "OrderedCollection",
      "totalItems" => 0,
      "orderedItems" => []
    }
  end

  def maybe_update_history(
        updated_object,
        orig_object_data,
        opts
      ) do
    updated = opts[:updated]
    use_history_in_new_object? = opts[:use_history_in_new_object?]

    if not updated do
      %{updated_object: updated_object, used_history_in_new_object?: false}
    else
      # Put edit history
      # Note that we may have got the edit history by first fetching the object
      {new_history, used_history_in_new_object?} =
        with true <- use_history_in_new_object?,
             updated_history when not is_nil(updated_history) <- maybe_history(opts[:new_data]) do
          {updated_history, true}
        else
          _ ->
            history = history_for(orig_object_data)

            latest_history_item =
              orig_object_data
              |> Map.drop(["id", "formerRepresentations"])

            updated_history =
              history
              |> Map.put("orderedItems", [latest_history_item | history["orderedItems"]])
              |> Map.put("totalItems", history["totalItems"] + 1)

            {updated_history, false}
        end

      updated_object =
        updated_object
        |> Map.put("formerRepresentations", new_history)

      %{updated_object: updated_object, used_history_in_new_object?: used_history_in_new_object?}
    end
  end

  defp maybe_update_poll(to_be_updated, updated_object) do
    choice_key = fn data ->
      if Map.has_key?(data, "anyOf"), do: "anyOf", else: "oneOf"
    end

    with true <- to_be_updated["type"] == "Question",
         key <- choice_key.(updated_object),
         true <- key == choice_key.(to_be_updated),
         orig_choices <- to_be_updated[key] |> Enum.map(&Map.drop(&1, ["replies"])),
         new_choices <- updated_object[key] |> Enum.map(&Map.drop(&1, ["replies"])),
         true <- orig_choices == new_choices do
      # Choices are the same, but counts are different
      to_be_updated
      |> Map.put(key, updated_object[key])
    else
      # Choices (or vote type) have changed, do not allow this
      _ -> to_be_updated
    end
  end

  # This calculates the data to be sent as the object of an Update.
  # new_data's formerRepresentations is not considered.
  # formerRepresentations is added to the returned data.
  def make_update_object_data(original_data, new_data, date) do
    %{data: updated_data, updated: updated} =
      original_data
      |> update_content_fields(new_data)

    if not updated do
      updated_data
    else
      %{updated_object: updated_data} =
        updated_data
        |> maybe_update_history(original_data, updated: updated, use_history_in_new_object?: false)

      updated_data
      |> Map.put("updated", date)
    end
  end

  # This calculates the data of the new Object from an Update.
  # new_data's formerRepresentations is considered.
  def make_new_object_data_from_update_object(original_data, new_data) do
    update_is_reasonable =
      with {_, updated} when not is_nil(updated) <- {:cur_updated, new_data["updated"]},
           {_, {:ok, updated_time, _}} <- {:cur_updated, DateTime.from_iso8601(updated)},
           {_, last_updated} when not is_nil(last_updated) <-
             {:last_updated, original_data["updated"] || original_data["published"]},
           {_, {:ok, last_updated_time, _}} <-
             {:last_updated, DateTime.from_iso8601(last_updated)},
           :gt <- DateTime.compare(updated_time, last_updated_time) do
        :update_everything
      else
        # only allow poll updates
        {:cur_updated, _} -> :no_content_update
        :eq -> :no_content_update
        # allow all updates
        {:last_updated, _} -> :update_everything
        # allow no updates
        _ -> false
      end

    %{
      updated_object: updated_data,
      used_history_in_new_object?: used_history_in_new_object?,
      updated: updated
    } =
      if update_is_reasonable == :update_everything do
        %{data: updated_data, updated: updated} =
          original_data
          |> update_content_fields(new_data)

        updated_data
        |> maybe_update_history(original_data,
          updated: updated,
          use_history_in_new_object?: true,
          new_data: new_data
        )
        |> Map.put(:updated, updated)
      else
        %{
          updated_object: original_data,
          used_history_in_new_object?: false,
          updated: false
        }
      end

    updated_data =
      if update_is_reasonable != false do
        updated_data
        |> maybe_update_poll(new_data)
      else
        updated_data
      end

    %{
      updated_data: updated_data,
      updated: updated,
      used_history_in_new_object?: used_history_in_new_object?
    }
  end

  def for_each_history_item(%{"orderedItems" => items} = history, _object, fun) do
    new_items =
      Enum.map(items, fun)
      |> Enum.reduce_while(
        {:ok, []},
        fn
          {:ok, item}, {:ok, acc} -> {:cont, {:ok, acc ++ [item]}}
          e, _acc -> {:halt, e}
        end
      )

    case new_items do
      {:ok, items} -> {:ok, Map.put(history, "orderedItems", items)}
      e -> e
    end
  end

  def for_each_history_item(history, _, _) do
    {:ok, history}
  end

  def do_with_history(object, fun) do
    with history <- object["formerRepresentations"],
         object <- Map.drop(object, ["formerRepresentations"]),
         {_, {:ok, object}} <- {:main_body, fun.(object)},
         {_, {:ok, history}} <- {:history_items, for_each_history_item(history, object, fun)} do
      object =
        if history do
          Map.put(object, "formerRepresentations", history)
        else
          object
        end

      {:ok, object}
    else
      {:main_body, e} -> e
      {:history_items, e} -> e
    end
  end
end
