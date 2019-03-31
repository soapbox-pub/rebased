defmodule Pleroma.BBS do
  def start_daemon do
    :ok = :ssh.start()

    options = [
      system_dir: 'ssh_keys',
      auth_method_kb_interactive_data: fn (_, user, _) -> {
        'Welcome to Pleroma BBS',
        'Hello #{user}',
        'Password: ',
        false }
      end,
      auth_methods: 'keyboard-interactive,password',
      pwdfun: fn(user, password) -> true end,
      shell: &start_prompt/1
    ]
    :ssh.daemon(13121, options)
  end

  def start_prompt(user) do
    spawn(__MODULE__, :prompt, [user])
  end

  def prompt(user) do
    IO.puts("Hey #{user}.\n")
    IO.puts("Here's your timeline:\n")

    user = Pleroma.User.get_cached_by_nickname(to_string(user))
    Pleroma.Web.TwitterAPI.TwitterAPI.fetch_friend_statuses(user)
    |> Enum.each(fn (status) ->
      IO.puts("#{status["user"]["name"]} (#{status["user"]["screen_name"]}): #{status["text"]}")
    end)
  end
end
