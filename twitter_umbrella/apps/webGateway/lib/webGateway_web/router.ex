defmodule WebGatewayWeb.Router do
  use WebGatewayWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    #plug OurAuth
    #plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WebGatewayWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/signup", PageController, :signup
    post "/do_signup", PageController, :do_signup
    post "/homepage", PageController, :do_login
    post "/search" , PageController, :search
    get "/logout", PageController, :logout
  end

  # Other scopes may use custom stacks.
  # scope "/api", WebGatewayWeb do
  #   pipe_through :api
  # end
end
