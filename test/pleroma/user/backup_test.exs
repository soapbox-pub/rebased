# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.BackupTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  import Pleroma.Factory
  import Swoosh.TestAssertions
  import Mox

  alias Pleroma.Bookmark
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.Uploaders.S3.ExAwsMock
  alias Pleroma.User.Backup
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.BackupWorker

  setup do
    clear_config([Pleroma.Upload, :uploader])
    clear_config([Backup, :limit_days])
    clear_config([Pleroma.Emails.Mailer, :enabled], true)

    ConfigMock
    |> stub_with(Pleroma.Config)

    :ok
  end

  test "it does not requrie enabled email" do
    clear_config([Pleroma.Emails.Mailer, :enabled], false)
    user = insert(:user)
    assert {:ok, _} = Backup.user(user)
  end

  test "it does not require user's email" do
    user = insert(:user, %{email: nil})
    assert {:ok, _} = Backup.user(user)
  end

  test "it creates a backup record and an Oban job" do
    user = insert(:user)
    assert {:ok, %Backup{} = backup} = Backup.user(user)
    assert {:ok, %Oban.Job{args: args}} = Backup.schedule_backup(backup)
    assert_enqueued(worker: BackupWorker, args: args)

    backup = Backup.get_by_id(args["backup_id"])
    assert %Backup{processed: false, file_size: 0} = backup
  end

  test "it return an error if the export limit is over" do
    user = insert(:user)
    limit_days = Pleroma.Config.get([Backup, :limit_days])
    {:ok, first_backup} = Backup.user(user)
    {:ok, _run_backup} = Backup.run(first_backup)

    assert Backup.user(user) == {:error, "Last export was less than #{limit_days} days ago"}
  end

  test "it process a backup record" do
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
    %{id: user_id} = user = insert(:user)

    assert {:ok, %Backup{id: backup_id}} = Backup.user(user)

    oban_args = %{"op" => "process", "backup_id" => backup_id}

    assert {:ok, backup} = perform_job(BackupWorker, oban_args)
    assert backup.file_size > 0
    assert match?(%Backup{id: ^backup_id, processed: true, user_id: ^user_id}, backup)

    delete_job_args = %{"op" => "delete", "backup_id" => backup_id}

    assert_enqueued(worker: BackupWorker, args: delete_job_args)
    assert {:ok, backup} = perform_job(BackupWorker, delete_job_args)
    refute Backup.get_by_id(backup_id)

    email = Pleroma.Emails.UserEmail.backup_is_ready_email(backup)

    assert_email_sent(
      to: {user.name, user.email},
      html_body: email.html_body
    )
  end

  test "it does not send an email if the user does not have an email" do
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
    %{id: user_id} = user = insert(:user, %{email: nil})

    assert {:ok, %Backup{} = backup} = Backup.user(user)

    expected_args = %{"op" => "process", "backup_id" => backup.id}

    assert_enqueued(worker: BackupWorker, args: %{"backup_id" => backup.id})
    assert {:ok, completed_backup} = perform_job(BackupWorker, expected_args)
    assert completed_backup.file_size > 0
    assert completed_backup.processed
    assert completed_backup.user_id == user_id

    assert_no_email_sent()
  end

  test "it does not send an email if mailer is not on" do
    clear_config([Pleroma.Emails.Mailer, :enabled], false)
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
    %{id: user_id} = user = insert(:user)

    assert {:ok, %Backup{id: backup_id}} = Backup.user(user)

    oban_args = %{"op" => "process", "backup_id" => backup_id}

    assert {:ok, backup} = perform_job(BackupWorker, oban_args)
    assert backup.file_size > 0
    assert match?(%Backup{id: ^backup_id, processed: true, user_id: ^user_id}, backup)

    assert_no_email_sent()
  end

  test "it does not send an email if the user has an empty email" do
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
    %{id: user_id} = user = insert(:user, %{email: ""})

    assert {:ok, %Backup{id: backup_id} = backup} = Backup.user(user)

    expected_args = %{"op" => "process", "backup_id" => backup.id}

    assert_enqueued(worker: BackupWorker, args: expected_args)

    assert {:ok, backup} = perform_job(BackupWorker, expected_args)
    assert backup.file_size > 0
    assert match?(%Backup{id: ^backup_id, processed: true, user_id: ^user_id}, backup)

    assert_no_email_sent()
  end

  test "it removes outdated backups after creating a fresh one" do
    clear_config([Backup, :limit_days], -1)
    clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
    user = insert(:user)

    assert {:ok, %{id: backup_one_id}} = Backup.user(user)
    assert {:ok, %{id: _backup_two_id}} = Backup.user(user)

    # Run the backups
    ObanHelpers.perform_all()

    assert_enqueued(worker: BackupWorker, args: %{"op" => "delete", "backup_id" => backup_one_id})
  end

  test "it creates a zip archive with user data" do
    user = insert(:user, %{nickname: "cofe", name: "Cofe", ap_id: "http://cofe.io/users/cofe"})
    %{ap_id: other_ap_id} = other_user = insert(:user)

    {:ok, %{object: %{data: %{"id" => id1}}} = status1} =
      CommonAPI.post(user, %{status: "status1"})

    {:ok, %{object: %{data: %{"id" => id2}}} = status2} =
      CommonAPI.post(user, %{status: "status2"})

    {:ok, %{object: %{data: %{"id" => id3}}} = status3} =
      CommonAPI.post(user, %{status: "status3"})

    CommonAPI.favorite(status1.id, user)
    CommonAPI.favorite(status2.id, user)

    Bookmark.create(user.id, status2.id)
    Bookmark.create(user.id, status3.id)

    CommonAPI.follow(other_user, user)

    assert {:ok, backup} = Backup.user(user)
    assert {:ok, run_backup} = Backup.run(backup)

    tempfile = Path.join([run_backup.tempdir, run_backup.file_name])

    assert {:ok, zipfile} = :zip.zip_open(String.to_charlist(tempfile), [:memory])
    assert {:ok, {~c"actor.json", json}} = :zip.zip_get(~c"actor.json", zipfile)

    assert %{
             "@context" => [
               "https://www.w3.org/ns/activitystreams",
               "http://localhost:4001/schemas/litepub-0.1.jsonld",
               %{"@language" => "und"}
             ],
             "bookmarks" => "bookmarks.json",
             "followers" => "http://cofe.io/users/cofe/followers",
             "following" => "http://cofe.io/users/cofe/following",
             "id" => "http://cofe.io/users/cofe",
             "inbox" => "http://cofe.io/users/cofe/inbox",
             "likes" => "likes.json",
             "name" => "Cofe",
             "outbox" => "http://cofe.io/users/cofe/outbox",
             "preferredUsername" => "cofe",
             "publicKey" => %{
               "id" => "http://cofe.io/users/cofe#main-key",
               "owner" => "http://cofe.io/users/cofe"
             },
             "type" => "Person",
             "url" => "http://cofe.io/users/cofe"
           } = Jason.decode!(json)

    assert {:ok, {~c"outbox.json", json}} = :zip.zip_get(~c"outbox.json", zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "outbox.json",
             "orderedItems" => [
               %{
                 "object" => %{
                   "actor" => "http://cofe.io/users/cofe",
                   "content" => "status1",
                   "type" => "Note"
                 },
                 "type" => "Create"
               },
               %{
                 "object" => %{
                   "actor" => "http://cofe.io/users/cofe",
                   "content" => "status2"
                 }
               },
               %{
                 "actor" => "http://cofe.io/users/cofe",
                 "object" => %{
                   "content" => "status3"
                 }
               }
             ],
             "totalItems" => 3,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    assert {:ok, {~c"likes.json", json}} = :zip.zip_get(~c"likes.json", zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "likes.json",
             "orderedItems" => [^id1, ^id2],
             "totalItems" => 2,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    assert {:ok, {~c"bookmarks.json", json}} = :zip.zip_get(~c"bookmarks.json", zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "bookmarks.json",
             "orderedItems" => [^id2, ^id3],
             "totalItems" => 2,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    assert {:ok, {~c"following.json", json}} = :zip.zip_get(~c"following.json", zipfile)

    assert %{
             "@context" => "https://www.w3.org/ns/activitystreams",
             "id" => "following.json",
             "orderedItems" => [^other_ap_id],
             "totalItems" => 1,
             "type" => "OrderedCollection"
           } = Jason.decode!(json)

    :zip.zip_close(zipfile)
    File.rm_rf!(run_backup.tempdir)
  end

  test "correct number processed" do
    user = insert(:user, %{nickname: "cofe", name: "Cofe", ap_id: "http://cofe.io/users/cofe"})

    Enum.map(1..120, fn i ->
      {:ok, status} = CommonAPI.post(user, %{status: "status #{i}"})
      CommonAPI.favorite(status.id, user)
      Bookmark.create(user.id, status.id)
    end)

    assert {:ok, backup} = user |> Backup.new() |> Repo.insert()
    {:ok, backup} = Backup.run(backup)

    zip_path = Path.join([backup.tempdir, backup.file_name])

    assert {:ok, zipfile} = :zip.zip_open(String.to_charlist(zip_path), [:memory])

    backup_parts = [~c"likes.json", ~c"bookmarks.json", ~c"outbox.json"]

    Enum.each(backup_parts, fn part ->
      assert {:ok, {_part, part_json}} = :zip.zip_get(part, zipfile)
      {:ok, decoded_part} = Jason.decode(part_json)
      assert decoded_part["totalItems"] == 120
    end)

    Backup.delete_archive(backup)
  end

  describe "it uploads and deletes a backup archive" do
    setup do
      clear_config([Pleroma.Upload, :base_url], "https://s3.amazonaws.com")
      clear_config([Pleroma.Uploaders.S3, :bucket], "test_bucket")

      user = insert(:user, %{nickname: "cofe", name: "Cofe", ap_id: "http://cofe.io/users/cofe"})

      {:ok, status1} = CommonAPI.post(user, %{status: "status1"})
      {:ok, status2} = CommonAPI.post(user, %{status: "status2"})
      {:ok, status3} = CommonAPI.post(user, %{status: "status3"})
      CommonAPI.favorite(status1.id, user)
      CommonAPI.favorite(status2.id, user)
      Bookmark.create(user.id, status2.id)
      Bookmark.create(user.id, status3.id)

      assert {:ok, backup} = user |> Backup.new() |> Repo.insert()

      [backup: backup]
    end

    test "S3", %{backup: backup} do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.S3)
      clear_config([Pleroma.Uploaders.S3, :streaming_enabled], false)

      ExAwsMock
      |> expect(:request, 2, fn
        %{http_method: :put} -> {:ok, :ok}
        %{http_method: :delete} -> {:ok, %{status_code: 204}}
      end)

      assert {:ok, backup} = Backup.run(backup)
      assert {:ok, %Backup{processed: true}} = Backup.upload(backup)
      assert {:ok, _backup} = Backup.delete_archive(backup)
    end

    test "Local", %{backup: backup} do
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)

      assert {:ok, backup} = Backup.run(backup)
      assert {:ok, %Backup{processed: true}} = Backup.upload(backup)
      assert {:ok, _backup} = Backup.delete_archive(backup)
    end
  end
end
