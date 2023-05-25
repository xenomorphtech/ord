defmodule Block do
    def post(method, params) do
        url = "http://localhost:#{Application.fetch_env!(:ord, :rpcport)}"
        headers = %{
            "Content-Type"=> "application/json",
            "Authorization"=> "Basic #{Application.fetch_env!(:ord, :rpcauth)}"
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

    def getrawtransaction(txid \\ "0de586d0c74780605c36c0f51dcd850d1772f41a92c549e3aa36f9e78e905284", verbose \\ true) do
        post("getrawtransaction", [txid, verbose])
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
        %{height: cur_height, previousblockhash: previousblockhash} = getblock(hash)
        last_indexed_block = MnesiaKV.get(MainChain, cur_height-1)
        cond do
            last_indexed_block.hash == previousblockhash -> start_height-cur_height
            true -> reorg_depth(start_height, previousblockhash)
        end
    end
end
