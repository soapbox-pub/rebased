# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.BackupControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User.Backup
  alias Pleroma.Web.PleromaAPI.BackupView

  setup do
    clear_config([Pleroma.Upload, :uploader])
    clear_config([Backup, :limit_days])
    oauth_access(["read:accounts"])
  end

  test "GET /api/v1/pleroma/backups", %{user: user, conn: conn} do
    assert {:ok, %Oban.Job{args: %{"backup_id" => backup_id}}} = Backup.create(user)

    backup = Backup.get(backup_id)

    response =
      conn
      |> get("/api/v1/pleroma/backups")
      |> json_response_and_validate_schema(:ok)

    assert [
             %{
               "content_type" => "application/zip",
               "url" => url,
               "file_size" => 0,
               "processed" => false,
               "inserted_at" => _
             }
           ] = response

    assert url == BackupView.download_url(backup)

    Pleroma.Tests.ObanHelpers.perform_all()

    assert [
             %{
               "url" => ^url,
               "processed" => true
             }
           ] =
             conn
             |> get("/api/v1/pleroma/backups")
             |> json_response_and_validate_schema(:ok)
  end

  test "POST /api/v1/pleroma/backups", %{user: _user, conn: conn} do
    assert [
             %{
               "content_type" => "application/zip",
               "url" => url,
               "file_size" => 0,
               "processed" => false,
               "inserted_at" => _
             }
           ] =
             conn
             |> post("/api/v1/pleroma/backups")
             |> json_response_and_validate_schema(:ok)

    Pleroma.Tests.ObanHelpers.perform_all()

    assert [
             %{
               "url" => ^url,
               "processed" => true
             }
           ] =
             conn
             |> get("/api/v1/pleroma/backups")
             |> json_response_and_validate_schema(:ok)

    days = Pleroma.Config.get([Backup, :limit_days])

    assert %{"error" => "Last export was less than #{days} days ago"} ==
             conn
             |> post("/api/v1/pleroma/backups")
             |> json_response_and_validate_schema(400)
  end

  test "Backup without email address" do
    user = Pleroma.Factory.insert(:user, email: nil)
    %{conn: conn} = oauth_access(["read:accounts"], user: user)

    assert is_nil(user.email)

    assert [
             %{
               "content_type" => "application/zip",
               "url" => _url,
               "file_size" => 0,
               "processed" => false,
               "inserted_at" => _
             }
           ] =
             conn
             |> post("/api/v1/pleroma/backups")
             |> json_response_and_validate_schema(:ok)
  end
end
