defmodule Worker.Registry do
    use GenServer
  
    ## Client API
  
    @doc """
    Starts the registry with the given options.
  
    `:name` is always required.
    """
    def start_link(opts) do
      # Pass the table names to GenServer's init
      proc_table = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, proc_table, opts)
    end

    def register(server, username, password) do
      GenServer.call(server, {:register, username, password})
    end

    def login(server, username, password) do
      GenServer.call(server, {:login, username, password})
    end
   
    ## Private

    #Ensures there is a proc associated to the given `name` in `server`.
    defp create(server, name) do
        GenServer.call(server, {:create, name})
        :ok
    end
  

    ## ETS CALLS
    @doc """
    Looks up the Proc pid for `name` stored in `server`.
  
    Returns `{:ok, pid}` if the proc exists, `:error` otherwise.
    """
    def lookup_proc(server, name) do
      # Lookup is done directly in ETS, without accessing the server
      case :ets.lookup(server, name) do
        [{^name, pid}] -> {:ok, pid}
        [] -> :error
      end
    end

    def lookup_tweet_string(twt_id) do
      # Lookup is done directly in ETS, without accessing the server
      case :ets.lookup(:tweet_table, twt_id) do
        [{twt_id, p_twt_id, twt}] -> inspect({twt_id, p_twt_id, twt})
        [] -> ""
      end
    end
    
    def lookup_tweet_tuple(twt_id) do
      # Lookup is done directly in ETS, without accessing the server
      case :ets.lookup(:tweet_table, twt_id) do
        [{twt_id, p_twt_id, twt}] -> {twt_id, p_twt_id, twt}
        [] -> {"", "", ""}
      end
    end

    def lookup_hashtag(hashtag) do
      # Lookup is done directly in ETS, without accessing the server
      case :ets.lookup(:hash_tag_table, hashtag) do
        [{^hashtag, twt_ids}] -> twt_ids
        [] -> []
      end
    end

    def put_tweet(tweet_tup) do
      # insert is done directly in ETS, without accessing the server
      :ets.insert(:tweet_table, tweet_tup)
    end
    
    def put_hashtag(hashtag, twt_id) do
      # insert is done directly in ETS, without accessing the server
      msg = 
        case lookup_hashtag(hashtag) do
          twt_ids -> {hashtag,[twt_id | twt_ids]}
          []  -> {hashtag, [twt_id]}
        end
      :ets.insert(:hash_tag_table, msg)
    end

    ## private
    defp lookup_user(username) do
      case :ets.lookup(:auth_table, username) do
        [{^username, password}] -> :found
        [] -> :not_found
      end
    end

    defp lookup_user(username, password) do
        case :ets.lookup(:auth_table, username) do
          [{user, passwd}] ->
            case password == passwd do
                true  -> :auth_approved
                false -> :auth_failure
            end
          [] -> :not_found
        end
    end

    defp put_user(username, password) do
      :ets.insert(:auth_table, {username, password})
      :ok
    end

  
    ## Server callbacks
    def init(proc_table) do
      :ets.new(:tweet_table, [:named_table, :public, write_concurrency: true])
      :ets.new(:hash_tag_table, [:named_table, :public, write_concurrency: true])
      :ets.new(:auth_table, [:named_table, :private])
      names = :ets.new(proc_table, [:named_table, read_concurrency: true])
      refs  = %{}
      {:ok, {names, refs}}
    end

    def handle_call({:register, username, password}, _from, {names, refs}) do
      msg = 
        with :not_found <- lookup_user(username),
        do: put_user(username, password)
      {:reply, msg, {names, refs}}
    end

    def handle_call({:login, name, password}, _from, {names, refs}) do
      msg =  
      case lookup_user(name,password) do
        :auth_approved ->
          if lookup_proc(names, name) == :error do
            {:ok, pid} = Worker.ProcSupervisor.start_proc()
            ref = Process.monitor(pid)
            refs = Map.put(refs, ref, name)
            :ets.insert(names, {name, pid})
            :ok
          else
            :ok
          end
        :auth_failure -> :auth_failure
        :not_found    -> :not_found
      end
      {:reply, msg, {names, refs}}
    end
  
    def handle_call({:create, name}, _from, {names, refs}) do
      case lookup_proc(names, name) do
        {:ok, pid} ->
          {:reply, pid, {names, refs}}
        :error ->
          {:ok, pid} = Worker.ProcSupervisor.start_proc()
          ref = Process.monitor(pid)
          refs = Map.put(refs, ref, name)
          :ets.insert(names, {name, pid})
          {:reply, pid, {names, refs}}
      end
    end
  
    def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
      {name, refs} = Map.pop(refs, ref)
      :ets.delete(names, name)
      {:noreply, {names, refs}}
    end
  
    def handle_info(_msg, state) do
      {:noreply, state}
    end
  end
  