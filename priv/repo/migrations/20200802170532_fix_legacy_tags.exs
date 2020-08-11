# Fix legacy tags set by AdminFE that don't align with TagPolicy MRF

defmodule Pleroma.Repo.Migrations.FixLegacyTags do
  use Ecto.Migration
  alias Pleroma.Repo
  alias Pleroma.User
  import Ecto.Query

  @old_new_map %{
    "force_nsfw" => "mrf_tag:media-force-nsfw",
    "strip_media" => "mrf_tag:media-strip",
    "force_unlisted" => "mrf_tag:force-unlisted",
    "sandbox" => "mrf_tag:sandbox",
    "disable_remote_subscription" => "mrf_tag:disable-remote-subscription",
    "disable_any_subscription" => "mrf_tag:disable-any-subscription"
  }

  def change do
    legacy_tags = Map.keys(@old_new_map)

    from(u in User,
      where: fragment("? && ?", u.tags, ^legacy_tags),
      select: struct(u, [:tags, :id])
    )
    |> Repo.chunk_stream(100)
    |> Enum.each(fn user ->
      fix_tags_changeset(user)
      |> Repo.update()
    end)
  end

  defp fix_tags_changeset(%User{tags: tags} = user) do
    new_tags =
      Enum.map(tags, fn tag ->
        Map.get(@old_new_map, tag, tag)
      end)

    Ecto.Changeset.change(user, tags: new_tags)
  end
end
