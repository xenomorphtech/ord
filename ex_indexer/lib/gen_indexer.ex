defmodule Ord.GenIndexer do
  use GenServer
  def start_link(), do: :gen_server.start_link(__MODULE__, [], [])
  def init([]) do
    :erlang.register(__MODULE__, self())
    :erlang.send_after(0, self(), :tick)
    Process.sleep(1000)
    {:ok, %{}}
  end

  def handle_info(:tick, state) do
    tick_delay = Process.get(:tick_delay, 1000)
    :erlang.send_after(tick_delay, self(), :tick)
    tick()
    {:noreply, state}
  end

  def tick() do
    fih = Application.fetch_env!(:ord, :first_inscription_height)
    next_process_index = :ets.last(MainChain)
    |> case do
        :"$end_of_table" -> fih
        idx -> idx + 1
    end

    %{height: cur_height, hash: hash} = Ord.Block.getbestblockhash()
    |> Ord.Block.getblock()
    cur_indexed_block = MnesiaKV.get(MainChain, cur_height)

    cond do
        cur_height < fih ->
            IO.puts "coinnode not synced to first inscription height - #{cur_height} / #{fih}"
        next_process_index < cur_height ->
            IO.puts "syncing inscriptions from #{next_process_index} to #{cur_height}"
            index_ordinal_block(next_process_index)
        #reorg occured
        cur_indexed_block.hash != hash ->
            depth = Ord.Block.reorg_depth(cur_height, hash)
            IO.puts "reorg detected at block #{cur_height} with a depth of #{depth}"
            #loading DB checkpoint from height x
            #MnesiaKV.restore_reflink MainChain, "/tmp/testz"

        Process.get(:tick_delay, 100) < 100 ->
            Process.put(:tick_delay, 1000)

        true ->
            Process.put(:tick_delay, 0)
            IO.puts "fun stuff time"
    end
  end

  #Ord.GenIndexer.index_ordinal_block(767430)
  #btrfs filesystem du db/
  def index_ordinal_block(index) do
    try do
        index_ordinal_block_1(index)
    catch
        e,r ->
            IO.inspect {:index_of_block_failed, index, e, r, __STACKTRACE__}
            path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup/#{index-1}"])
            MnesiaKV.restore_reflink(MainChain, path)
            MnesiaKV.restore_reflink(Ord, path)
    end
  end

  def index_ordinal_block_1(index) do
      block = Ord.Block.getblockhash(index)
      |> Ord.Block.getblock()
      |> Map.take([:hash, :nextblockhash, :previousblockhash, :height, :nTx, :time, :weight])
      MnesiaKV.merge(MainChain, index, block)

      Ord.BlockOrd.proc_ord_transactions(block.hash)

      path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup/#{index}"])
      MnesiaKV.backup_reflink(MainChain, path)
      MnesiaKV.backup_reflink(Ord, path)
  end
end
