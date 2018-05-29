defmodule Gateway.Connection do
    require Logger
  
    def accept(port) do
      # The options below mean:
      #
      # 1. `:binary` - receives data as binaries (instead of lists)
      # 2. `packet: :line` - receives data line by line
      # 3. `active: false` - blocks on `:gen_tcp.recv/2` until data is available
      # 4. `reuseaddr: true` - allows us to reuse the address if the listener crashes
      #
      {:ok, socket} = :gen_tcp.listen(port,
                        [:binary, packet: :line, active: false, reuseaddr: true])
      Logger.info "Accepting connections on port #{port}"
      loop_acceptor(socket)
    end
  
    defp loop_acceptor(socket) do
      {:ok, client} = :gen_tcp.accept(socket)
      {:ok, pid} = Task.Supervisor.start_child(Gateway.ListenTaskSupervisor, fn -> serve(client) end)
      :ok = :gen_tcp.controlling_process(client, pid)
      loop_acceptor(socket)
    end
  
    defp serve(socket) do
      msg =
        with {:ok, data} <- read_line(socket),
             {:ok, command} <- Gateway.Command.parse(data),
             do: Gateway.Command.run(command)
  
      write_line(socket, msg)
      serve(socket)
    end
  
    defp read_line(socket) do
      :gen_tcp.recv(socket, 0)
    end
  
    defp write_line(socket, {:ok, text}) do
      :gen_tcp.send(socket, text)
    end
  
    defp write_line(socket, {:error, :user_not_found}) do
      :gen_tcp.send(socket, "USER NOT FOUND\r\n")
    end

    defp write_line(socket, {:error, :auth_failure}) do
      :gen_tcp.send(socket, "AUTHENTICATION FAILED\r\n")
    end
  
    defp write_line(socket, {:error, :unknown_command}) do
      # Known error. Write to the client.
      :gen_tcp.send(socket, "UNKNOWN COMMAND\r\n")
    end
  
    defp write_line(_socket, {:error, :closed}) do
      # The connection was closed, exit politely.
      exit(:shutdown)
    end
  
    defp write_line(socket, {:error, error}) do
      # Unknown error. Write to the client and exit.
      :gen_tcp.send(socket, "ERROR\r\n")
      exit(error)
    end

    defp write_line(socket, {:msg, msg}) do
        # Some Message. Write to the client.
        :gen_tcp.send(socket, msg)
      end
  end
  