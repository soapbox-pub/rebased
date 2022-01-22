# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ModerationLog do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Query

  @type t :: %__MODULE__{}
  @type log_subject :: Activity.t() | User.t() | list(User.t())
  @type log_params :: %{
          required(:actor) => User.t(),
          required(:action) => String.t(),
          optional(:subject) => log_subject(),
          optional(:subject_actor) => User.t(),
          optional(:subject_id) => String.t(),
          optional(:subjects) => list(User.t()),
          optional(:permission) => String.t(),
          optional(:text) => String.t(),
          optional(:sensitive) => String.t(),
          optional(:visibility) => String.t(),
          optional(:followed) => User.t(),
          optional(:follower) => User.t(),
          optional(:nicknames) => list(String.t()),
          optional(:tags) => list(String.t()),
          optional(:target) => String.t()
        }

  schema "moderation_log" do
    field(:data, :map)

    timestamps()
  end

  def get_all(params) do
    base_query =
      get_all_query()
      |> maybe_filter_by_date(params)
      |> maybe_filter_by_user(params)
      |> maybe_filter_by_search(params)

    query_with_pagination = base_query |> paginate_query(params)

    %{
      items: Repo.all(query_with_pagination),
      count: Repo.aggregate(base_query, :count, :id)
    }
  end

  defp maybe_filter_by_date(query, %{start_date: nil, end_date: nil}), do: query

  defp maybe_filter_by_date(query, %{start_date: start_date, end_date: nil}) do
    from(q in query,
      where: q.inserted_at >= ^parse_datetime(start_date)
    )
  end

  defp maybe_filter_by_date(query, %{start_date: nil, end_date: end_date}) do
    from(q in query,
      where: q.inserted_at <= ^parse_datetime(end_date)
    )
  end

  defp maybe_filter_by_date(query, %{start_date: start_date, end_date: end_date}) do
    from(q in query,
      where: q.inserted_at >= ^parse_datetime(start_date),
      where: q.inserted_at <= ^parse_datetime(end_date)
    )
  end

  defp maybe_filter_by_user(query, %{user_id: nil}), do: query

  defp maybe_filter_by_user(query, %{user_id: user_id}) do
    from(q in query,
      where: fragment("(?)->'actor'->>'id' = ?", q.data, ^user_id)
    )
  end

  defp maybe_filter_by_search(query, %{search: search}) when is_nil(search) or search == "",
    do: query

  defp maybe_filter_by_search(query, %{search: search}) do
    from(q in query,
      where: fragment("(?)->>'message' ILIKE ?", q.data, ^"%#{search}%")
    )
  end

  defp paginate_query(query, %{page: page, page_size: page_size}) do
    from(q in query,
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
  end

  defp get_all_query do
    from(q in __MODULE__,
      order_by: [desc: q.inserted_at]
    )
  end

  defp parse_datetime(datetime) do
    {:ok, parsed_datetime, _} = DateTime.from_iso8601(datetime)

    parsed_datetime
  end

  defp prepare_log_data(%{actor: actor, action: action} = attrs) do
    %{
      "actor" => user_to_map(actor),
      "action" => action,
      "message" => ""
    }
    |> Pleroma.Maps.put_if_present("subject_actor", user_to_map(attrs[:subject_actor]))
  end

  defp prepare_log_data(attrs), do: attrs

  @spec insert_log(log_params()) :: {:ok, ModerationLog} | {:error, any}
  def insert_log(%{actor: %User{}, subject: subjects, permission: permission} = attrs) do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"subject" => user_to_map(subjects), "permission" => permission})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{actor: %User{}, action: action, subject: %Activity{} = subject} = attrs)
      when action in ["report_note_delete", "report_update", "report_note"] do
    data =
      attrs
      |> prepare_log_data
      |> Pleroma.Maps.put_if_present("text", attrs[:text])
      |> Map.merge(%{"subject" => report_to_map(subject)})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(
        %{
          actor: %User{},
          action: action,
          subject: %Activity{} = subject,
          sensitive: sensitive,
          visibility: visibility
        } = attrs
      )
      when action == "status_update" do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{
        "subject" => status_to_map(subject),
        "sensitive" => sensitive,
        "visibility" => visibility
      })

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{actor: %User{}, action: action, subject_id: subject_id} = attrs)
      when action == "status_delete" do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"subject_id" => subject_id})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{actor: %User{}, subject: subject, action: _action} = attrs) do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"subject" => user_to_map(subject)})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{actor: %User{}, subjects: subjects, action: _action} = attrs) do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"subjects" => user_to_map(subjects)})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(
        %{
          actor: %User{},
          followed: %User{} = followed,
          follower: %User{} = follower,
          action: action
        } = attrs
      )
      when action in ["unfollow", "follow"] do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"followed" => user_to_map(followed), "follower" => user_to_map(follower)})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{
        actor: %User{} = actor,
        nicknames: nicknames,
        tags: tags,
        action: action
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "nicknames" => nicknames,
        "tags" => tags,
        "action" => action,
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  def insert_log(%{actor: %User{}, action: action, target: target} = attrs)
      when action in ["relay_follow", "relay_unfollow"] do
    data =
      attrs
      |> prepare_log_data
      |> Map.merge(%{"target" => target})

    insert_log_entry_with_message(%ModerationLog{data: data})
  end

  def insert_log(%{actor: %User{} = actor, action: "chat_message_delete", subject_id: subject_id}) do
    %ModerationLog{
      data: %{
        "actor" => %{"nickname" => actor.nickname},
        "action" => "chat_message_delete",
        "subject_id" => subject_id
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log_entry_with_message(ModerationLog) :: {:ok, ModerationLog} | {:error, any}
  defp insert_log_entry_with_message(entry) do
    entry.data["message"]
    |> put_in(get_log_entry_message(entry))
    |> Repo.insert()
  end

  defp user_to_map(users) when is_list(users) do
    Enum.map(users, &user_to_map/1)
  end

  defp user_to_map(%User{} = user) do
    user
    |> Map.take([:id, :nickname])
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Map.put("type", "user")
  end

  defp user_to_map(_), do: nil

  defp report_to_map(%Activity{} = report) do
    %{"type" => "report", "id" => report.id, "state" => report.data["state"]}
  end

  defp status_to_map(%Activity{} = status) do
    %{"type" => "status", "id" => status.id}
  end

  @spec get_log_entry_message(ModerationLog.t()) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => action,
          "followed" => %{"nickname" => followed_nickname},
          "follower" => %{"nickname" => follower_nickname}
        }
      }) do
    "@#{actor_nickname} made @#{follower_nickname} #{action} @#{followed_nickname}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "delete",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} deleted users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "create",
          "subjects" => subjects
        }
      }) do
    "@#{actor_nickname} created users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "activate",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} activated users: #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "deactivate",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} deactivated users: #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "approve",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} approved users: #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "add_suggestion",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} added suggested users: #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "remove_suggestion",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} removed suggested users: #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "nicknames" => nicknames,
          "tags" => tags,
          "action" => "tag"
        }
      }) do
    tags_string = tags |> Enum.join(", ")

    "@#{actor_nickname} added tags: #{tags_string} to users: #{nicknames_to_string(nicknames)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "nicknames" => nicknames,
          "tags" => tags,
          "action" => "untag"
        }
      }) do
    tags_string = tags |> Enum.join(", ")

    "@#{actor_nickname} removed tags: #{tags_string} from users: #{nicknames_to_string(nicknames)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "grant",
          "subject" => users,
          "permission" => permission
        }
      }) do
    "@#{actor_nickname} made #{users_to_nicknames_string(users)} #{permission}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "revoke",
          "subject" => users,
          "permission" => permission
        }
      }) do
    "@#{actor_nickname} revoked #{permission} role from #{users_to_nicknames_string(users)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "relay_follow",
          "target" => target
        }
      }) do
    "@#{actor_nickname} followed relay: #{target}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "relay_unfollow",
          "target" => target
        }
      }) do
    "@#{actor_nickname} unfollowed relay: #{target}"
  end

  def get_log_entry_message(
        %ModerationLog{
          data: %{
            "actor" => %{"nickname" => actor_nickname},
            "action" => "report_update",
            "subject" => %{"id" => subject_id, "state" => state, "type" => "report"}
          }
        } = log
      ) do
    "@#{actor_nickname} updated report ##{subject_id}" <>
      subject_actor_nickname(log, " (on user ", ")") <>
      " with '#{state}' state"
  end

  def get_log_entry_message(
        %ModerationLog{
          data: %{
            "actor" => %{"nickname" => actor_nickname},
            "action" => "report_note",
            "subject" => %{"id" => subject_id, "type" => "report"},
            "text" => text
          }
        } = log
      ) do
    "@#{actor_nickname} added note '#{text}' to report ##{subject_id}" <>
      subject_actor_nickname(log, " on user ")
  end

  def get_log_entry_message(
        %ModerationLog{
          data: %{
            "actor" => %{"nickname" => actor_nickname},
            "action" => "report_note_delete",
            "subject" => %{"id" => subject_id, "type" => "report"},
            "text" => text
          }
        } = log
      ) do
    "@#{actor_nickname} deleted note '#{text}' from report ##{subject_id}" <>
      subject_actor_nickname(log, " on user ")
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_update",
          "subject" => %{"id" => subject_id, "type" => "status"},
          "sensitive" => nil,
          "visibility" => visibility
        }
      }) do
    "@#{actor_nickname} updated status ##{subject_id}, set visibility: '#{visibility}'"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_update",
          "subject" => %{"id" => subject_id, "type" => "status"},
          "sensitive" => sensitive,
          "visibility" => nil
        }
      }) do
    "@#{actor_nickname} updated status ##{subject_id}, set sensitive: '#{sensitive}'"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_update",
          "subject" => %{"id" => subject_id, "type" => "status"},
          "sensitive" => sensitive,
          "visibility" => visibility
        }
      }) do
    "@#{actor_nickname} updated status ##{subject_id}, set sensitive: '#{sensitive}', visibility: '#{visibility}'"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_delete",
          "subject_id" => subject_id
        }
      }) do
    "@#{actor_nickname} deleted status ##{subject_id}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "force_password_reset",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} forced password reset for users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "confirm_email",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} confirmed email for users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "resend_confirmation_email",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} re-sent confirmation email for users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "updated_users",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} updated users: #{users_to_nicknames_string(subjects)}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "chat_message_delete",
          "subject_id" => subject_id
        }
      }) do
    "@#{actor_nickname} deleted chat message ##{subject_id}"
  end

  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "create_backup",
          "subject" => %{"nickname" => user_nickname}
        }
      }) do
    "@#{actor_nickname} requested account backup for @#{user_nickname}"
  end

  defp nicknames_to_string(nicknames) do
    nicknames
    |> Enum.map(&"@#{&1}")
    |> Enum.join(", ")
  end

  defp users_to_nicknames_string(users) do
    users
    |> Enum.map(&"@#{&1["nickname"]}")
    |> Enum.join(", ")
  end

  defp subject_actor_nickname(%ModerationLog{data: data}, prefix_msg, postfix_msg \\ "") do
    case data do
      %{"subject_actor" => %{"nickname" => subject_actor}} ->
        [prefix_msg, "@#{subject_actor}", postfix_msg]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join()

      _ ->
        ""
    end
  end
end
