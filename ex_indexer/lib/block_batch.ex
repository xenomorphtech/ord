defmodule BlockBatch do
    # BlockBatch.block_txs_from_to 767431, 767431+3
    def block_txs_from_to(index, to_index) when is_integer(index) do
        batch_tx = Enum.map(index..to_index, fn(idx)->
            "{\"jsonrpc\":\"1.0\",\"id\":#{idx},\"method\":\"getblockhash\",\"params\":[#{idx}]}"
        end)
        |> Enum.join(",")
        batch_tx = "["<>batch_tx<>"]"

        url = "http://localhost:#{Application.fetch_env!(:ord, :rpcport)}"
        headers = %{
            "Content-Type"=> "application/json",
            "Authorization"=> "Basic #{Application.fetch_env!(:ord, :rpcauth)}"
        }
        %{body: body} = Photon.HTTP.request("POST", url, headers, batch_tx, %{json_opts: [{:labels, :atom}]})

        batch_tx = Enum.map(body, fn(%{id: id, result: hash})->
            "{\"jsonrpc\":\"1.0\",\"id\":#{id},\"method\":\"getblock\",\"params\":[\"#{hash}\"]}"
        end)
        |> Enum.join(",")
        batch_tx = "["<>batch_tx<>"]"
        %{body: blocks} = Photon.HTTP.request("POST", url, headers, batch_tx, %{json_opts: [{:labels, :atom}]})
        blocks = Enum.sort_by(blocks, & &1.id)
        |> Enum.map(& &1.result)

        batch_tx = Enum.map(blocks, fn(%{height: height, tx: txs})->
            Enum.map(Enum.with_index(txs), fn({tx, tx_idx})->
                "{\"jsonrpc\":\"1.0\",\"id\":\"#{height}_#{tx_idx}\",\"method\":\"getrawtransaction\",\"params\":[\"#{tx}\",true]}"
            end)
        end)
        |> List.flatten()
        |> Enum.join(",")
        batch_tx = "["<>batch_tx<>"]"
        %{body: body} = Photon.HTTP.request("POST", url, headers, batch_tx, %{timeout: 600_000, json_opts: [{:labels, :atom}]})
        
        txs = Enum.sort_by(body, & &1.id)
        |> Enum.map(fn(%{id: id, result: result})->
            [height, txindex] = :binary.split(id, "_")
            height = :erlang.binary_to_integer(height)
            txindex = :erlang.binary_to_integer(txindex)
            %{height: height, txindex: txindex, result: result}
        end)

        Enum.map(blocks, fn(block)->
            block_txs = for tx <- txs, tx.height == block.height, do: tx.result
            Map.put(block, :tx, block_txs)
        end)
    end
end