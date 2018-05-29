defmodule Gateway.Command do
    @doc ~S"""
    Parses the given `line` into a command.
  
    ## Examples
  
    """
    def parse(line) do
      case String.split(line) do
        ["REGISTER", username, password] -> {:ok, {:register, username, password}}
        ["LOGIN", username, password] -> {:ok, {:login, username, password}}
        ["LOGOUT", username] -> {:ok, {:logout, username}}
        ["TIMELINE", username] -> {:ok, {:get_timeline, username}}
        ["TWEET" | rest] -> {:ok, {:tweet, rest}}
        ["RETWEET", username, twt_id] -> {:ok, {:retweet, username, twt_id}}
        ["SEARCH", username, hashtag] -> {:ok, {:search, username, hashtag}}
        ["MYMENTION", username] -> {:ok, {:my_mention, username}}
        ["FOLLOW" | rest ] -> {:ok, {:follow, rest}}
        _ -> {:error, :unknown_command}
      end
    end
  
    @doc """
    Runs the given command.
    """
    def run(command)
    
    ## CALL CALLS
    def run({:register, username, password}) do
      case Worker.Registry.register(Worker.Registry, username, password) do
        :ok -> {:ok, "OK\r\n"}
        :found -> {:msg , "#{username} ALREADY EXISTS\r\n"}
        {:error, error} -> {:error, error}
      end
    end
  
    def run({:login, username, password}) do
      case Worker.Registry.login(Worker.Registry, username, password) do
        :ok ->
          lookup username , fn pid -> 
            value = Worker.Proc.login(pid, username)
            case value do
              :ok -> {:ok, "OK\r\n"}
              {:msg, msg} -> {:msg, "#{msg}\r\n"}
              {:error, error} -> {:error, error}
            end
          end
        :auth_failure -> {:error, :auth_failure}
        :not_found -> {:error, :user_not_found}
        {:error, error} -> {:error, error}
      end
    end
    
    def run({:get_timeline, username}) do 
      lookup username, fn pid ->
        value = Worker.Proc.get_timeline(pid, username) 
          case value do
            {:ok, timeline} -> {:ok, "#{timeline}\r\n"}
            {:msg, msg} -> {:msg, "#{msg}\r\n"}
            {:error, error} -> {:error, error}
          end
      end
    end

    def run({:search, username, hashtag}) do
      lookup username, fn pid ->
        value = Worker.Proc.search(pid, username, hashtag) 
          case value do
            {:ok, result} -> {:ok, "#{result}\r\n"}
            {:msg, msg} -> {:msg, "#{msg}\r\n"}
            {:error, error} -> {:error, error}
          end
      end
    end

    def run({:my_mention, username}) do
      lookup username, fn pid ->
        value = Worker.Proc.my_mention(pid, username) 
          case value do
            {:ok, result} -> {:ok, "#{result}\r\n"}
            {:msg, msg} -> {:msg, "#{msg}\r\n"}
            {:error, error} -> {:error, error}
          end
      end
    end
    
    ## CAST CALLS
    def run({:logout, username}) do 
      lookup username, fn pid ->
        Worker.Proc.logout(pid, username)
        {:ok, "OK\r\n"} 
      end
    end

    def run({:tweet, rest}) do
      [username | rest] = rest 
      twt = rest
      lookup username, fn pid ->
        Worker.Proc.tweet(pid, username, twt)
        {:ok, "OK\r\n"} 
      end
    end

    def run({:retweet, username, twt_id}) do 
      lookup username, fn pid ->
        Worker.Proc.retweet(pid, username, twt_id)
        {:ok, "OK\r\n"} 
      end
    end

    def run({:follow, rest}) do 
      [username | users_to_follow] = rest
      lookup username, fn pid ->
        Worker.Proc.follow(pid, username, users_to_follow)
        {:ok, "OK\r\n"} 
      end
    end
    
    ## PRIVATE METTHOD
    defp lookup(username, callback) do
      case Worker.Registry.lookup_proc(Worker.Registry, username) do
        {:ok, pid} -> callback.(pid)
        :error -> {:error, :user_not_found}
      end
    end
end