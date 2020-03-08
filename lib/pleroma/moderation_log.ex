defmodule Pleroma.ModerationLog do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Query

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

  @spec insert_log(%{actor: User, subject: [User], action: String.t(), permission: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        subject: subjects,
        action: action,
        permission: permission
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "subject" => user_to_map(subjects),
        "action" => action,
        "permission" => permission,
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, subject: User, action: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: "report_update",
        subject: %Activity{data: %{"type" => "Flag"}} = subject
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "report_update",
        "subject" => report_to_map(subject),
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, subject: Activity, action: String.t(), text: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: "report_note",
        subject: %Activity{} = subject,
        text: text
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "report_note",
        "subject" => report_to_map(subject),
        "text" => text
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, subject: Activity, action: String.t(), text: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: "report_note_delete",
        subject: %Activity{} = subject,
        text: text
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "report_note_delete",
        "subject" => report_to_map(subject),
        "text" => text
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{
          actor: User,
          subject: Activity,
          action: String.t(),
          sensitive: String.t(),
          visibility: String.t()
        }) :: {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: "status_update",
        subject: %Activity{} = subject,
        sensitive: sensitive,
        visibility: visibility
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "status_update",
        "subject" => status_to_map(subject),
        "sensitive" => sensitive,
        "visibility" => visibility,
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, action: String.t(), subject_id: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: "status_delete",
        subject_id: subject_id
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "status_delete",
        "subject_id" => subject_id,
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, subject: User, action: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{actor: %User{} = actor, subject: subject, action: action}) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => action,
        "subject" => user_to_map(subject),
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, subjects: [User], action: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{actor: %User{} = actor, subjects: subjects, action: action}) do
    subjects = Enum.map(subjects, &user_to_map/1)

    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => action,
        "subjects" => subjects,
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, action: String.t(), followed: User, follower: User}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        followed: %User{} = followed,
        follower: %User{} = follower,
        action: "follow"
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "follow",
        "followed" => user_to_map(followed),
        "follower" => user_to_map(follower),
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{actor: User, action: String.t(), followed: User, follower: User}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        followed: %User{} = followed,
        follower: %User{} = follower,
        action: "unfollow"
      }) do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => "unfollow",
        "followed" => user_to_map(followed),
        "follower" => user_to_map(follower),
        "message" => ""
      }
    }
    |> insert_log_entry_with_message()
  end

  @spec insert_log(%{
          actor: User,
          action: String.t(),
          nicknames: [String.t()],
          tags: [String.t()]
        }) :: {:ok, ModerationLog} | {:error, any}
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

  @spec insert_log(%{actor: User, action: String.t(), target: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{
        actor: %User{} = actor,
        action: action,
        target: target
      })
      when action in ["relay_follow", "relay_unfollow"] do
    %ModerationLog{
      data: %{
        "actor" => user_to_map(actor),
        "action" => action,
        "target" => target,
        "message" => ""
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
    users |> Enum.map(&user_to_map/1)
  end

  defp user_to_map(%User{} = user) do
    user
    |> Map.from_struct()
    |> Map.take([:id, :nickname])
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Map.put("type", "user")
  end

  defp report_to_map(%Activity{} = report) do
    %{
      "type" => "report",
      "id" => report.id,
      "state" => report.data["state"]
    }
  end

  defp status_to_map(%Activity{} = status) do
    %{
      "type" => "status",
      "id" => status.id
    }
  end

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

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "delete",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} deleted users: #{users_to_nicknames_string(subjects)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "create",
          "subjects" => subjects
        }
      }) do
    "@#{actor_nickname} created users: #{users_to_nicknames_string(subjects)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "activate",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} activated users: #{users_to_nicknames_string(users)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "deactivate",
          "subject" => users
        }
      }) do
    "@#{actor_nickname} deactivated users: #{users_to_nicknames_string(users)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "relay_follow",
          "target" => target
        }
      }) do
    "@#{actor_nickname} followed relay: #{target}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "relay_unfollow",
          "target" => target
        }
      }) do
    "@#{actor_nickname} unfollowed relay: #{target}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "report_update",
          "subject" => %{"id" => subject_id, "state" => state, "type" => "report"}
        }
      }) do
    "@#{actor_nickname} updated report ##{subject_id} with '#{state}' state"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "report_note",
          "subject" => %{"id" => subject_id, "type" => "report"},
          "text" => text
        }
      }) do
    "@#{actor_nickname} added note '#{text}' to report ##{subject_id}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "report_note_delete",
          "subject" => %{"id" => subject_id, "type" => "report"},
          "text" => text
        }
      }) do
    "@#{actor_nickname} deleted note '#{text}' from report ##{subject_id}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
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

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_update",
          "subject" => %{"id" => subject_id, "type" => "status"},
          "sensitive" => sensitive,
          "visibility" => visibility
        }
      }) do
    "@#{actor_nickname} updated status ##{subject_id}, set sensitive: '#{sensitive}', visibility: '#{
      visibility
    }'"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "status_delete",
          "subject_id" => subject_id
        }
      }) do
    "@#{actor_nickname} deleted status ##{subject_id}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "force_password_reset",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} forced password reset for users: #{users_to_nicknames_string(subjects)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "confirm_email",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} confirmed email for users: #{users_to_nicknames_string(subjects)}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "resend_confirmation_email",
          "subject" => subjects
        }
      }) do
    "@#{actor_nickname} re-sent confirmation email for users: #{
      users_to_nicknames_string(subjects)
    }"
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
end
