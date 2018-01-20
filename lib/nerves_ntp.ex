defmodule NervesNTP do
  use Task, restart: :permanent

  @daemon_sync_period Application.get_env(:nerves_ntp, :daemon_sync_period, 12 * 60 * 60 * 1000)

  def start_link(sync_on_start: sync_on_start) do
    if sync_on_start do
      NervesNTP.Cmd.sync(true)
    end

    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Process.sleep(@daemon_sync_period)
    NervesNTP.Cmd.sync(false)
    run()
  end
end

defmodule NervesNTP.Cmd do
  @moduledoc """
  Synchronizes time using busybox `ntpd` command.

  Primary use is for [Nerves](http://nerves-project.org) embedded devices.
  """
  require Logger

  @timeout Application.get_env(:nerves_ntp, :timeout, 20_000)
  @on_error_restart_period Application.get_env(:nerves_ntp, :on_error_restart_period, 5_000)

  @ntpd Application.get_env(:nerves_ntp, :ntpd, "/usr/sbin/ntpd")
  @servers Application.get_env(:nerves_ntp, :servers, [
             "0.pool.ntp.org",
             "1.pool.ntp.org",
             "2.pool.ntp.org",
             "3.pool.ntp.org"
           ])
  @ntpd_cmd "#{@ntpd} -n -q -N #{Enum.map_join(@servers, " ", &"-p #{&1}")}"

  @doc """
  Start NTPD synchronization.

  If `block` is `true` the function will block till a sync successfully complete.
  """
  @spec sync(boolean) :: :ok | :error
  def sync(block \\ false) do
    Logger.info("NervesNTP sync")

    task = Task.async(&run_ntpd/0)
    result = Task.await(task, :infinity)

    if block and result == :error do
      Process.sleep(@on_error_restart_period)
      sync(block)
    else
      result
    end
  end

  defp run_ntpd() do
    port =
      Port.open({:spawn, @ntpd_cmd}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:line, 2048}
      ])

    timer = Process.send_after(self(), :timeout, @timeout)

    wait_response(port, timer)
  end

  defp wait_response(port, timer) do
    receive do
      :timeout ->
        do_exit(:error, port, timer)

      {^port, {:exit_status, code}} ->
        Logger.debug("exit #{inspect(code)}")

        if code == 0 do
          do_exit(:ok, port, timer)
        else
          do_exit(:error, port, timer)
        end

      {^port, {:data, {:eol, "ntpd: bad address " <> _address = data}}} ->
        Logger.debug("#{inspect(data)}")
        do_exit(:error, port, timer)

      {^port, data} ->
        Logger.debug("#{inspect(data)}")
        wait_response(port, timer)
    end
  end

  defp do_exit(result, port, timer) do
    Process.cancel_timer(timer)

    if result == :error do
      # close and check for zombie process
      case Port.info(port, :os_pid) do
        {:os_pid, os_pid} ->
          Port.close(port)
          System.cmd("kill", [Integer.to_string(os_pid)])

        _ ->
          :ok
      end
    end

    result
  end
end
