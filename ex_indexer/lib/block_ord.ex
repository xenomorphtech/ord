defmodule Ord.BlockOrd do
    def proc_ord_transactions(index) when is_integer(index) do
        Ord.Block.getblockhash(index)
        |> proc_ord_transactions()
    end

    # Ord.Block.proc_ord_transactions(767430)
    # Ord.Block.proc_ord_transactions(779832)
    #:erlang.spawn(fn()-> Ord.Block.proc_ord_transactions(767430) end)
    def proc_ord_transactions(blockhash) do
      block = Ord.Block.getblock(blockhash)
      batch_tx = Enum.map(Enum.with_index(block.tx), fn({txid,idx})->
        "{\"jsonrpc\":\"1.0\",\"id\":#{idx},\"method\":\"getrawtransaction\",\"params\":[\"#{txid}\",true]}"
      end)
      |> Enum.join(",")
      batch_tx = "["<>batch_tx<>"]"

      url = "http://localhost:8332"
      headers = %{
          "Content-Type"=> "application/json",
          "Authorization"=> "Basic b3JkOm9yZA==" #ord:ord
      }
      %{body: body} = Photon.HTTP.request("POST", url, headers, batch_tx, %{json_opts: [{:labels, :atom}]})
      true = length(body) == length(block.tx)
      txs = Enum.sort_by(body, & &1.id)
      |> Enum.map(& &1.result)

      next_ord_index = :ets.last(Ord)
      |> case do
          :"$end_of_table" -> 0
          idx -> idx + 1
      end
      Enum.reduce(txs, next_ord_index, fn(tx_obj, next_ord_index)->
          txinwitness = hd(tx_obj.vin)[:txinwitness] || []
          potential_ord = (Enum.at(txinwitness, -2) || "")
          |> Base.decode16!(case: :lower)
          case read_ord(potential_ord) do
            nil -> next_ord_index
            %{body: body} ->
              owner = hd(tx_obj.vout).scriptPubKey.address
              ord = %{body: body, txid: tx_obj.txid, blockhash: blockhash, blockheight: block.height, owner: owner}
              MnesiaKV.merge(Ord, next_ord_index, ord)
              next_ord_index + 1
          end
      end)
    end

    #Ord.Block.read_ord Base.decode16!(h, case: :lower)
    def read_ord(bin) do
        case bin do
          <<0x20, pubkey::binary-32, 0xac, rest::binary>> ->
              #some transfers insert junk like <<6, 69, 121, 255, 234, 135, 1, 117, 0, 99>>
              #so skip to the if
              case :binary.split(rest, <<0,0x63, 3,"ord", 1,1>>) do
                [_, <<sct, ct::binary-size(sct), 0x00, rest::binary>>] ->
                  body = read_ord_body(rest)
                  %{content_type: ct, body: body}
                _ -> nil
              end
          _ -> nil
        end
    end

    def read_ord_body(bin, acc \\ "") do
        case bin do
            #OP_ENDIF
            <<0x68>> -> acc
            #N/A Push
            <<size, payload::binary-size(size), rest::binary>> when size in 0x01..0x4b ->
                read_ord_body(rest, acc <> payload)
            #OP_PUSHDATA1
            <<0x4c, size, payload::binary-size(size), rest::binary>> ->
                read_ord_body(rest, acc <> payload)
            #OP_PUSHDATA2
            <<0x4d, size::16-little, payload::binary-size(size), rest::binary>> -> 
                read_ord_body(rest, acc <> payload)
        end
    end
end