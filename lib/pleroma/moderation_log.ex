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

  def get_all(page, page_size) do
    from(q in __MODULE__,
      order_by: [desc: q.inserted_at],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  def insert_log(%{
        actor: %User{} = actor,
        subject: %User{} = subject,
        action: action,
        permission: permission
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        subject: user_to_map(subject),
        action: action,
        permission: permission
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        action: "report_update",
        subject: %Activity{data: %{"type" => "Flag"}} = subject
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "report_update",
        subject: report_to_map(subject)
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        action: "report_response",
        subject: %Activity{} = subject,
        text: text
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "report_response",
        subject: report_to_map(subject),
        text: text
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        action: "status_update",
        subject: %Activity{} = subject,
        sensitive: sensitive,
        visibility: visibility
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "status_update",
        subject: status_to_map(subject),
        sensitive: sensitive,
        visibility: visibility
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        action: "status_delete",
        subject_id: subject_id
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "status_delete",
        subject_id: subject_id
      }
    })
  end

  @spec insert_log(%{actor: User, subject: User, action: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{actor: %User{} = actor, subject: subject, action: action}) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: action,
        subject: user_to_map(subject)
      }
    })
  end

  @spec insert_log(%{actor: User, subjects: [User], action: String.t()}) ::
          {:ok, ModerationLog} | {:error, any}
  def insert_log(%{actor: %User{} = actor, subjects: subjects, action: action}) do
    subjects = Enum.map(subjects, &user_to_map/1)

    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: action,
        subjects: subjects
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        followed: %User{} = followed,
        follower: %User{} = follower,
        action: "follow"
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "follow",
        followed: user_to_map(followed),
        follower: user_to_map(follower)
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        followed: %User{} = followed,
        follower: %User{} = follower,
        action: "unfollow"
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: "unfollow",
        followed: user_to_map(followed),
        follower: user_to_map(follower)
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        nicknames: nicknames,
        tags: tags,
        action: action
      }) do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        nicknames: nicknames,
        tags: tags,
        action: action
      }
    })
  end

  def insert_log(%{
        actor: %User{} = actor,
        action: action,
        target: target
      })
      when action in ["relay_follow", "relay_unfollow"] do
    Repo.insert(%ModerationLog{
      data: %{
        actor: user_to_map(actor),
        action: action,
        target: target
      }
    })
  end

  defp user_to_map(%User{} = user) do
    user
    |> Map.from_struct()
    |> Map.take([:id, :nickname])
    |> Map.put(:type, "user")
  end

  defp report_to_map(%Activity{} = report) do
    %{
      type: "report",
      id: report.id,
      state: report.data["state"]
    }
  end

  defp status_to_map(%Activity{} = status) do
    %{
      type: "status",
      id: status.id
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
          "subject" => %{"nickname" => subject_nickname, "type" => "user"}
        }
      }) do
    "@#{actor_nickname} deleted user @#{subject_nickname}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "create",
          "subjects" => subjects
        }
      }) do
    nicknames =
      subjects
      |> Enum.map(&"@#{&1["nickname"]}")
      |> Enum.join(", ")

    "@#{actor_nickname} created users: #{nicknames}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "activate",
          "subject" => %{"nickname" => subject_nickname, "type" => "user"}
        }
      }) do
    "@#{actor_nickname} activated user @#{subject_nickname}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "deactivate",
          "subject" => %{"nickname" => subject_nickname, "type" => "user"}
        }
      }) do
    "@#{actor_nickname} deactivated user @#{subject_nickname}"
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
    nicknames_string =
      nicknames
      |> Enum.map(&"@#{&1}")
      |> Enum.join(", ")

    tags_string = tags |> Enum.join(", ")

    "@#{actor_nickname} added tags: #{tags_string} to users: #{nicknames_string}"
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
    nicknames_string =
      nicknames
      |> Enum.map(&"@#{&1}")
      |> Enum.join(", ")

    tags_string = tags |> Enum.join(", ")

    "@#{actor_nickname} removed tags: #{tags_string} from users: #{nicknames_string}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "grant",
          "subject" => %{"nickname" => subject_nickname},
          "permission" => permission
        }
      }) do
    "@#{actor_nickname} made @#{subject_nickname} #{permission}"
  end

  @spec get_log_entry_message(ModerationLog) :: String.t()
  def get_log_entry_message(%ModerationLog{
        data: %{
          "actor" => %{"nickname" => actor_nickname},
          "action" => "revoke",
          "subject" => %{"nickname" => subject_nickname},
          "permission" => permission
        }
      }) do
    "@#{actor_nickname} revoked #{permission} role from @#{subject_nickname}"
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
          "action" => "report_response",
          "subject" => %{"id" => subject_id, "type" => "report"},
          "text" => text
        }
      }) do
    "@#{actor_nickname} responded with '#{text}' to report ##{subject_id}"
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
end
