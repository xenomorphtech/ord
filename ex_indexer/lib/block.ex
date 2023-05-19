defmodule Ord.Block do
    def post(method, params) do
        url = "http://localhost:8332"
        headers = %{
            "Content-Type"=> "application/json",
            "Authorization"=> "Basic b3JkOm9yZA==" #ord:ord
        }
        body = JSX.encode!(%{
            jsonrpc: "1.0",
            id: "test",
            method: method,
            params: params
        })
        %{body: body} = Photon.HTTP.request("POST", url, headers, body, %{json_opts: [{:labels, :atom}]})
        body
    end

    def getblockhash(index \\ 0) do
        post("getblockhash", [index])
        |> Map.fetch!(:result)
    end

    def getbestblockhash() do
        post("getbestblockhash", [])
        |> Map.fetch!(:result)
    end

    def getblock(hash \\ "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f") do
        post("getblock", [hash])
        |> Map.fetch!(:result)
    end

    def getrawtransaction(txid \\ "0de586d0c74780605c36c0f51dcd850d1772f41a92c549e3aa36f9e78e905284", verbose \\ true, blockhash \\ nil) do
        params = if blockhash do [txid, verbose, blockhash] else
            [txid, verbose]
        end
        post("getrawtransaction", params)
        |> Map.fetch!(:result)
    end

    def decoderawtransaction(tx_raw) do
        post("decoderawtransaction", [tx_raw])
        |> Map.fetch!(:result)
    end

    def decodescript(hex) do
        post("decodescript", [hex])
    end

    # functions
    def reorg_depth(start_height, hash) do
        %{height: cur_height, previousblockhash: previousblockhash} = Ord.Block.getblock(hash)
        last_indexed_block = MnesiaKV.get(MainChain, cur_height-1)
        cond do
            last_indexed_block.hash == previousblockhash -> start_height-cur_height
            true -> reorg_depth(start_height, previousblockhash)
        end
    end

    def get_ord_transactions(index) when is_integer(index) do
        getblockhash(index)
        |> get_ord_transactions()
    end

    def get_ord_transactions(blockhash) do
      block = Ord.Block.getblock(blockhash)
      Enum.reduce(block.tx, [], fn(tx,acc)->
          tx_obj = Ord.Block.getrawtransaction(tx, true, blockhash)
          txinwitness = hd(tx_obj.vin)[:txinwitness] || []
          potential_ord = (Enum.at(txinwitness, -2) || "")
          |> Base.decode16!(case: :lower)
          if String.starts_with?(potential_ord, <<0x20>>) do
            IO.inspect potential_ord
          end
          case potential_ord do
            <<0x20, pubkey::binary-32, 0xac, rest::binary>> ->
                #some transfers insert junk like <<6, 69, 121, 255, 234, 135, 1, 117, 0, 99>>
                #so skip to the if
                [_, <<sct, ct::binary-size(sct), 0x00, rest::binary>>] = :binary.split(rest, <<0,0x63, 3,"ord", 1,1>>)
                body = read_ord_body(rest)
                ord = %{pubkey: pubkey, content_type: ct, body: body}
                IO.inspect {:found_ord, pubkey, ct, body}
                acc ++ [ord]
            _ -> acc
          end
      end)
    end

    def read_ord_body(bin, acc \\ "") do
        case bin do
            #OP_ENDIF
            <<0x68>> -> acc
            #OP_PUSHDATA1
            <<0x4c, size, payload::binary-size(size), rest::binary>> ->
                read_ord_body(rest, acc <> payload)
            #OP_PUSHDATA2
            <<0x4d, size::16-little, payload::binary-size(size), rest::binary>> -> 
                read_ord_body(rest, acc <> payload)
        end
    end
end
