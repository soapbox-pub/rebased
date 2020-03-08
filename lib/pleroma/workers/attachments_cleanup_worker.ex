# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.AttachmentsCleanupWorker do
  import Ecto.Query

  alias Pleroma.Object
  alias Pleroma.Repo

  use Pleroma.Workers.WorkerHelper, queue: "attachments_cleanup"

  @impl Oban.Worker
  def perform(
        %{
          "op" => "cleanup_attachments",
          "object" => %{"data" => %{"attachment" => [_ | _] = attachments, "actor" => actor}}
        },
        _job
      ) do
    hrefs =
      Enum.flat_map(attachments, fn attachment ->
        Enum.map(attachment["url"], & &1["href"])
      end)

    names = Enum.map(attachments, & &1["name"])

    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    # find all objects for copies of the attachments, name and actor doesn't matter here
    delete_ids =
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
      # we should delete 1 object for any given attachment, but don't delete
      # files if there are more than 1 object for it
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
      |> Enum.map(fn {href, %{id: id, count: count}} ->
        # only delete files that have single instance
        with 1 <- count do
          prefix =
            case Pleroma.Config.get([Pleroma.Upload, :base_url]) do
              nil -> "media"
              _ -> ""
            end

          base_url =
            String.trim_trailing(
              Pleroma.Config.get([Pleroma.Upload, :base_url], Pleroma.Web.base_url()),
              "/"
            )

          file_path = String.trim_leading(href, "#{base_url}/#{prefix}")

          uploader.delete_file(file_path)
        end

        id
      end)

    from(o in Object, where: o.id in ^delete_ids)
    |> Repo.delete_all()
  end

  def perform(%{"op" => "cleanup_attachments", "object" => _object}, _job), do: :ok
end
