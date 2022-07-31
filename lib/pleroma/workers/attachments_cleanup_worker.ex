# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.AttachmentsCleanupWorker do
  import Ecto.Query

  alias Pleroma.Object
  alias Pleroma.Repo

  use Pleroma.Workers.WorkerHelper, queue: "attachments_cleanup"

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "op" => "cleanup_attachments",
          "object" => %{"data" => %{"attachment" => [_ | _] = attachments, "actor" => actor}}
        }
      }) do
    if Pleroma.Config.get([:instance, :cleanup_attachments], false) do
      attachments
      |> Enum.flat_map(fn item -> Enum.map(item["url"], & &1["href"]) end)
      |> fetch_objects
      |> prepare_objects(actor, Enum.map(attachments, & &1["name"]))
      |> filter_objects
      |> do_clean
    end

    {:ok, :success}
  end

  def perform(%Job{args: %{"op" => "cleanup_attachments", "object" => _object}}), do: {:ok, :skip}

  defp do_clean({object_ids, attachment_urls}) do
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    base_url =
      String.trim_trailing(
        Pleroma.Upload.base_url(),
        "/"
      )

    Enum.each(attachment_urls, fn href ->
      href
      |> String.trim_leading("#{base_url}")
      |> uploader.delete_file()
    end)

    delete_objects(object_ids)
  end

  defp delete_objects([_ | _] = object_ids) do
    Repo.delete_all(from(o in Object, where: o.id in ^object_ids))
  end

  defp delete_objects(_), do: :ok

  # we should delete 1 object for any given attachment, but don't delete
  # files if there are more than 1 object for it
  defp filter_objects(objects) do
    Enum.reduce(objects, {[], []}, fn {href, %{id: id, count: count}}, {ids, hrefs} ->
      with 1 <- count do
        {ids ++ [id], hrefs ++ [href]}
      else
        _ -> {ids ++ [id], hrefs}
      end
    end)
  end

  defp prepare_objects(objects, actor, names) do
    objects
    |> Enum.reduce(%{}, fn %{
                             id: id,
                             data: %{
                               "url" => [%{"href" => href}],
                               "actor" => obj_actor,
                               "name" => name
                             }
                           },
                           acc ->
      Map.update(acc, href, %{id: id, count: 1}, fn val ->
        case obj_actor == actor and name in names do
          true ->
            # set id of the actor's object that will be deleted
            %{val | id: id, count: val.count + 1}

          false ->
            # another actor's object, just increase count to not delete file
            %{val | count: val.count + 1}
        end
      end)
    end)
  end

  defp fetch_objects(hrefs) do
    from(o in Object,
      where:
        fragment(
          "to_jsonb(array(select jsonb_array_elements((?)#>'{url}') ->> 'href' where jsonb_typeof((?)#>'{url}') = 'array'))::jsonb \\?| (?)",
          o.data,
          o.data,
          ^hrefs
        )
    )
    # The query above can be time consumptive on large instances until we
    # refactor how uploads are stored
    |> Repo.all(timeout: :infinity)
  end
end
