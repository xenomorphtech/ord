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

    %{height: cur_height, hash: hash} = Block.getbestblockhash()
    |> Block.getblock()
    cur_indexed_block = MnesiaKV.get(MainChain, cur_height)

    cond do
        cur_height < fih ->
            IO.puts "coinnode not synced to first inscription height - #{cur_height} / #{fih}"
        next_process_index < cur_height ->
            nil
            IO.puts "syncing inscriptions from #{next_process_index} to #{cur_height}"
            index_ordinal_blocks(next_process_index, min(next_process_index+3, cur_height))
        #reorg occured
        cur_indexed_block.hash != hash ->
            depth = Block.reorg_depth(cur_height, hash)
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

  #Ord.GenIndexer.index_ordinal_blocks(767430,767430+3)
  def index_ordinal_blocks(from, to) do
    try do
        index_ordinal_blocks_1(from, to)
    catch
        e,r ->
            IO.inspect {:index_of_block_failed, from, to, e, r, __STACKTRACE__}
            Process.sleep(100_000_000)
            #path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup/#{index-1}"])
            #MnesiaKV.restore_reflink(MainChain, path)
            #MnesiaKV.restore_reflink(Ord, path)
    end
  end

  def index_ordinal_blocks_1(from, to) do
      blocks = BlockBatch.block_txs_from_to(from, to)
      Enum.each(blocks, fn(block)->
        block_clean = Map.take(block, [:hash, :nextblockhash, :previousblockhash, :height, :nTx, :time, :weight])
        
        batchkv = [{:insert, MainChain, block.height, block_clean}]
        #FlatKV.merge(MainChain, block.height, block_clean)
        batchkv = batchkv ++ proc_ord_transactions(block)
        IO.inspect batchkv

        mainChain = Enum.filter(batchkv, & elem(&1,1) == MainChain)
        ord = Enum.filter(batchkv, & elem(&1,1) == Ord)
        ordHistory = Enum.filter(batchkv, & elem(&1,1) == OrdHistory)
        FlatKV.batch(MainChain, mainChain)
        FlatKV.batch(Ord, ord)
        FlatKV.batch(OrdHistory, ordHistory)

        checkpoint_db(block.height)
      end)
  end

  def proc_ord_transactions(block) do
    next_ord_index = :ets.last(Ord)
    |> case do
        :"$end_of_table" -> 0
        idx -> idx + 1
    end

    Enum.reduce(block.tx, next_ord_index, fn(tx_obj, next_ord_index)->
        txinwitness = hd(tx_obj.vin)[:txinwitness] || []
        potential_ord = (Enum.at(txinwitness, -2) || "")
        |> Base.decode16!(case: :lower)
        case Ord.read(potential_ord) do
          nil ->
              proc_ord_transfers(block, tx_obj)
              next_ord_index
          %{content_type: content_type, body: body} ->
            owner = hd(tx_obj.vout).scriptPubKey.address
            ord = %{index: next_ord_index, content_type: content_type, body: body,
              txid: tx_obj.txid, txid_current: tx_obj.txid,
              blockhash: block.hash, blockheight: block.height, owner: owner}
            Process.put(:ordmap, Map.put(Process.get(:ordmap, %{}), tx_obj.txid, next_ord_index))
            Process.put(:batchkv, Process.get(:batchkv, []) ++ [{:insert, Ord, next_ord_index, ord}])
            ord_history = %{txid: tx_obj.txid, sender: owner, receiver: owner, blockheight: block.height, ord: next_ord_index}
            Process.put(:batchkv, Process.get(:batchkv, []) ++ [{:insert, OrdHistory, tx_obj.txid, ord_history}])
            #FlatKV.merge(Ord, next_ord_index, ord)
            next_ord_index + 1
        end
    end)

    Process.delete(:ordmap)
    batchkv = Process.get(:batchkv, [])
    Process.delete(:batchkv)
    batchkv
  end

  def proc_ord_transfers(block, tx_obj) do
    txid = hd(tx_obj.vin)[:txid]
    case Map.get(Process.get(:ordmap, %{}), txid) do
        nil -> nil
        ord -> 
            new_txid = tx_obj.txid
            new_owner = hd(tx_obj.vout).scriptPubKey.address
            IO.inspect {Ord, ord.index, :transfer, new_owner}

            Process.put(:batchkv, Process.get(:batchkv, []) ++ [{:merge, Ord, ord.index, %{txid_current: new_txid, owner: new_owner}}])
            ord_history = %{txid: tx_obj.txid, sender: ord.owner, receiver: new_owner, blockheight: block.height, ord: ord.index}
            Process.put(:batchkv, Process.get(:batchkv, []) ++ [{:insert, OrdHistory, tx_obj.txid, ord_history}])
            #FlatKV.merge(ord_index, %{txid_current: new_txid, owner: new_owner})
    end
  end

  def checkpoint_db(index) do
    path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup/#{index}"])
    File.mkdir_p!(path)
    FlatKV.snapshot(MainChain, path)
    FlatKV.snapshot(Ord, path)
    FlatKV.snapshot(OrdHistory, path)
    #%{db: db, args: args} = :persistent_term.get({:mnesia_kv_db, MainChain})
    #:rocksdb.compact_range(db, :undefined, :undefined, [{:exclusive_manual_compaction, true}, {:allow_write_stall, true}])
    #:rocksdb.compact_range(db, ['000009.sst'], :undefined, [{:exclusive_manual_compaction, true}, {:allow_write_stall, true}])

    #:rocksdb.flush(db, [{:wait, true},{:allow_write_stall, true}])

    #path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup/#{index}"])
    #File.mkdir_p!(path)
    #%{db: db, args: args} = :persistent_term.get({:mnesia_kv_db, MainChain})
    #:rocksdb.checkpoint(db, :erlang.binary_to_list(path<>"/#{MainChain}"))
    #%{db: db, args: args} = :persistent_term.get({:mnesia_kv_db, Ord})
    #:rocksdb.checkpoint(db, :erlang.binary_to_list(path<>"/#{Ord}"))
  end
end
