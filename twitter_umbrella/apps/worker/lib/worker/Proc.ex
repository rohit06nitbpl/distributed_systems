defmodule Worker.Proc do
    use GenServer, restart: :temporary
  
    ## Client APIs

    #calls
    def start_link(opts) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end
    
    def login(server, username) do
      GenServer.call(server,{:login, username})
    end

    def is_logged_in(server,username) do
      GenServer.call(server,{:is_logged_in, username})
    end

    def get_followers(server,username) do
      GenServer.call(server,{:get_followers, username})
    end

    def get_timeline(server, username) do
      GenServer.call(server,{:get_timeline})  
    end

    def search(server, username, hashtag) do
      GenServer.call(server,{:search, username, hashtag})  
    end

    def my_mention(server, username) do
      GenServer.call(server,{:my_mention})  
    end
    
    ## casts
    def logout(server, username) do
      GenServer.cast(server, {:logout})  
    end

    def tweet(server, username, twt) do
      GenServer.cast(server, {:tweet, username, twt})  
    end

    def retweet(server, username, twt_id) do
      GenServer.cast(server, {:retweet, username, twt_id})  
    end

    def follow(server, username, users_to_follow) do
      GenServer.cast(server, {:follow, username, users_to_follow})   
    end

    ##gui cast
    def cast_homepage(server, username) do
      GenServer.cast(server, {:cast_homepage, username})
    end
    
    ## server callbacks

    def init(:ok) do
      is_logged_in = false  
      time_line = []
      my_mention = []
      followers = []
      {:ok, {is_logged_in, time_line, my_mention, followers}}
    end
    
    
    def handle_call({:login, username}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:msg, "USER ALREADY LOGGED IN"}
          false -> :ok
        end
      {:reply, msg, {true, time_line, my_mention, followers}}
    end
    
    def handle_call({:is_logged_in, username}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:ok,true}
          false -> {:ok,false}
        end
      {:reply, msg, {is_logged_in, time_line, my_mention, followers}}
    end

    def handle_call({:get_followers}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:ok, followers}
          false -> {:msg, "USER NOT LOGGED IN"}
        end
      {:reply, msg, {is_logged_in, time_line, my_mention, followers}}
    end

    defp get_tweet(twt_ids) do
      Enum.map(twt_ids, fn(x) -> Worker.Registry.lookup_tweet_string(x) end) |> Enum.join("\r\n")
    end
    def handle_call({:get_timeline}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:ok, get_tweet(time_line)}
          false -> {:msg, "USER NOT LOGGED IN"}
        end
      {:reply, msg, {is_logged_in, time_line, my_mention, followers}}
    end
    
    defp search_tweet(username, hashtag) do
        Worker.Registry.lookup_hashtag(hashtag) |> get_tweet
    end
    def handle_call({:search, username, hashtag}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:ok, search_tweet(username, hashtag)}
          false -> {:msg, "USER NOT LOGGED IN"}
        end

        WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "search_result", %{result: elem(msg,1)}
      {:reply, msg, {is_logged_in, time_line, my_mention, followers}}
    end

    def handle_call({:my_mention}, _from, {is_logged_in, time_line, my_mention, followers}) do
      msg = 
        case is_logged_in do
          true  -> {:ok, get_tweet(my_mention)}
          false -> {:msg, "USER NOT LOGGED IN"}
        end
      {:reply, msg, {is_logged_in, time_line, my_mention, followers}}
    end
    
    def handle_cast({:logout}, {is_logged_in, time_line, my_mention, followers}) do
      {:noreply, {false, time_line, my_mention, followers}}  
    end
    
    defp send_tweetid(users, twt_id) do
      users_ids = Enum.map(users, fn(x) -> {elem(Worker.Registry.lookup_proc(Worker.Registry, x),1),x} end)
      Enum.each(users_ids, fn({pid,username}) -> GenServer.cast(pid, {:send_tweetid, twt_id, username }) end)  
    end
    def handle_cast({:tweet, username, twt}, {is_logged_in, time_line, my_mention, followers}) do
      if is_logged_in do
        twt_id = "#{username}-#{:os.system_time(:millisecond)}"
        #words = String.split(twt)
        words = twt
        twt = words |> Enum.join(" ")
        if words != [] do
          mentions = words |> Enum.filter(fn(x) -> String.at(x, 0) == "@" end)
          hashtags = words |> Enum.filter(fn(x) -> String.at(x, 0) == "#" end)
          {mymention, mentions} = Enum.split_with(mentions, fn(x) -> x == "@#{username}" end)
  
          users = Enum.map(mentions, fn(x) ->  String.slice(x , 1..-1) end) ++ followers
          
          Worker.Registry.put_tweet({twt_id, "-1", twt})
          Enum.each(hashtags, fn(hashtag) -> Worker.Registry.put_hashtag(hashtag, twt_id) end)
          
          send_tweetid(users,twt_id)
         
          if mymention != [] do
              my_mention  = [ twt_id | my_mention ]
          end
          time_line = [twt_id|time_line]
          time_line_object = %{twt_id: twt_id, p_twt_id: "-1", body: twt}
          WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "time_line", %{timeline: time_line_object}
        end  
      else
        IO.puts ":tweet #{username} not logged in"
      end
      
      {:noreply, {is_logged_in, time_line, my_mention, followers}}  
    end

    def handle_cast({:send_tweetid, twt_id, username}, {is_logged_in, time_line, my_mention, followers}) do
      {twt_id,p_twt_id,twt} = Worker.Registry.lookup_tweet_tuple(twt_id)
      time_line_object = %{twt_id: twt_id, p_twt_id: "-1", body: twt}
      WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "time_line", %{timeline: time_line_object}
      {:noreply, {is_logged_in, [twt_id|time_line] , my_mention, followers}} 
    end
    
    defp not_my_tweet(twt_id, username) do
      #IO.inspect hd(String.split(twt_id, "-"))
      #IO.inspect username
      hd(String.split(twt_id, "-")) != username
    end
    def handle_cast({:retweet, username, twt_id}, {is_logged_in, time_line, my_mention, followers}) do
      if is_logged_in and not_my_tweet(twt_id, username) do
        {twt_id, p_twt_id, twt} = Worker.Registry.lookup_tweet_tuple(twt_id)
        rtwt_id = "#{username}-#{:os.system_time(:millisecond)}"
        words = String.split(twt)
        if words != [] do
          mentions = words |> Enum.filter(fn(x) -> String.at(x, 0) == "@" end)
          hashtags = words |> Enum.filter(fn(x) -> String.at(x, 0) == "#" end)
          {mymention, mentions} = Enum.split_with(mentions, fn(x) -> x == "@#{username}" end)
  
          users = Enum.map(mentions, fn(x) ->  String.slice(x , 1..-1) end) ++ followers
          Worker.Registry.put_tweet({rtwt_id, twt_id, twt})
          Enum.each(hashtags, fn(hashtag) -> Worker.Registry.put_hashtag(hashtag, rtwt_id) end)
  
          send_tweetid(users,rtwt_id)
  
          if mymention != [] do
            my_mention  = [ rtwt_id | my_mention ]
          end
  
          time_line = [rtwt_id|time_line]
          time_line_object = %{twt_id: rtwt_id, p_twt_id: twt_id, body: twt}
          WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "time_line", %{timeline: time_line_object}
        end  
      else
        IO.puts ":retweet #{username} not logged in or #{username} is tweeting its own tweet"
      end  
      {:noreply, {is_logged_in, time_line , my_mention, followers}} 
    end

    def handle_cast({:follow, username, users_to_follow}, {is_logged_in, time_line, my_mention, followers}) do
      if is_logged_in do
        users_ids = Enum.map(users_to_follow, fn(x) ->{ elem(Worker.Registry.lookup_proc(Worker.Registry, x),1), x} end)  
        Enum.each(users_ids, fn({p_pid,p_username}) -> GenServer.cast(p_pid, {:add_follower, username, p_username}) end)
      else
        IO.puts ":follow #{username} not logged in"
      end  
      {:noreply, {is_logged_in, time_line , my_mention, followers}}
    end

    def handle_cast({:add_follower, username, p_username}, {is_logged_in, time_line, my_mention, followers}) do
      if not Enum.member?(followers,username) do
        followers = [username|followers]
      end
      IO.inspect p_username
      IO.inspect followers
      WebGatewayWeb.Endpoint.broadcast! "user:"<>p_username, "n_follower", %{count: Enum.count(followers)}
      {:noreply, {is_logged_in, time_line , my_mention, followers}} 
    end

    def handle_cast({:cast_homepage, username}, {is_logged_in, time_line, my_mention, followers}) do
      if is_logged_in do
        WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "n_follower", %{count: Enum.count(followers)}
        time_line_tuple = Enum.map(time_line, fn(x) -> Worker.Registry.lookup_tweet_tuple(x) end) 
        time_line_object = Enum.map(time_line_tuple, fn(x) -> %{twt_id: elem(x,0), p_twt_id: elem(x,1) , body: elem(x,2)} end)
        WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "time_line", %{timeline: time_line_object}
      else
        IO.puts ":cast_homepage #{username} not logged in"
      end
      

      {:noreply, {is_logged_in, time_line , my_mention, followers}} 
    end
end