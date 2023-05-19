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
            tx = Ord.Block.get_ord_transactions(next_process_index)
            IO.inspect tx
            #index_ordinal_block(next_process_index)
        #reorg occured
        cur_indexed_block.hash != hash ->
            depth = Ord.Block.reorg_depth(cur_height, hash)
            IO.puts "reorg detected at block #{cur_height} with a depth of #{depth}"
            #loading DB checkpoint from height x

        Process.get(:tick_delay, 100) < 100 ->
            Process.put(:tick_delay, 1000)

        true ->
            Process.put(:tick_delay, 0)
            IO.puts "fun stuff time"
    end
  end

  def index_mainchain_block(index) do
    hash = Ord.Block.getblockhash(index)
    if !hash do
        :invalid_index
    else
        block = Ord.Block.getblock(hash)
        |> Map.take([:hash, :nextblockhash, :previousblockhash, :height, :nTx, :time, :weight])
        MnesiaKV.merge(MainChain, index, block)
        nil
    end
  end

  def index_ordinal_block(index) do
      block = Ord.Block.getblockhash(index)
      |> Ord.Block.getblock()

      IO.inspect block
      Enum.reduce_while(block.tx, nil, fn(tx,_)->
          tx_obj = Ord.Block.getrawtransaction(tx, true, block.hash)
          txwitness = hd(tx_obj.vin)[:txinwitness]
          cond do
            !txwitness or length(txwitness) < 3 -> nil
            String.starts_with?(Enum.at(txwitness,1), "20") -> IO.inspect tx_obj
            true -> nil
          end
          {:cont, nil}
      end)
      
      #get block
      #get all tx
      #filter out non-ordinal tx
  end
end
