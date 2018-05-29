defmodule WebGatewayWeb.PageController do
  use WebGatewayWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def send_homepage(conn, pid, username) do
    conn = conn |> assign(:username, username)
    token = Phoenix.Token.sign(conn, "user socket", username)
    conn = assign(conn, :user_token, token)
    render conn, "homepage.html", conn.assigns
    
  end

  def logout(conn, %{"username" => username}) do
    lookup username, fn pid -> value = Worker.Proc.logout(pid, username) end
    redirect conn, to: "/"
  end

  def search(conn, %{"param" => param}) do
    %{"search-qr" => hashtag, "username" => username} = param
    IO.inspect username
    conn = conn |> assign(:username, username)
    lookup username, fn pid ->
      value = Worker.Proc.search(pid, username, hashtag) 
        case value do
          {:ok, result} -> WebGatewayWeb.Endpoint.broadcast! "user:"<>username, "search_result", %{"result" => result}
          render conn, "search.html" ,conn.assigns
          {:msg, msg} -> conn #{:msg, "#{msg}\r\n"}
          {:error, error} -> {:error, error}
        end
    end

  end


  def do_login(conn, %{"user" => user}) do
    {:ok,username} = Map.fetch(user,"username")
    {:ok,password} = Map.fetch(user, "password")
    case Worker.Registry.login(Worker.Registry, username, password) do
      :ok ->
        lookup username , fn pid -> 
          value = Worker.Proc.login(pid, username)
          case value do
            :ok -> send_homepage(conn, pid, username)
            {:msg, "USER ALREADY LOGGED IN"} -> send_homepage(conn, pid, username)
            {:msg,msg} -> html conn, """
            <html>
              <head>
                Message: #{msg}
              </head>
              <body>
                <a href = "http://localhost:4000">Go Back</a>
              </body>
            </html>
            """
            {:error, error} -> {:error, error}
          end
        end
      :auth_failure -> html conn, """
      <html>
        <head>
          Authentication Failure!!
        </head>
        <body>
          <a href = "http://localhost:4000">Go Back</a>
        </body>
      </html>
      """
      :not_found -> html conn, """
      <html>
        <head>
           username #{username} not found!!
        </head>
        <body>
          <a href = "http://localhost:4000">Go Back</a>
        </body>
      </html>
      """
      {:error, error} -> {:error, error}
    end
    
  end

  def signup(conn, _params) do
    render conn, "signup.html"
  end

  def do_signup(conn, %{"user" => user}) do
    {:ok,username} = Map.fetch(user,"username")
    {:ok,password} = Map.fetch(user, "password")
    case Worker.Registry.register(Worker.Registry, username, password) do
      :ok -> redirect conn, to: "/"
      :found -> html conn, """
      <html>
        <head>
           username #{username} ALREADY EXISTS
        </head>
        <body>
          <a href = "http://localhost:4000/signup">Go Back</a>
        </body>
      </html>
      """
      {:error, error} -> {:error, error}
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
