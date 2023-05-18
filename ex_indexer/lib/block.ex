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
        %{body: body} = Photon.HTTP.request("POST", url, headers, body)
        body
    end

    def getblockhash(index \\ 0) do
        post("getblockhash", [index])
    end

    def getblock(hash \\ "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f") do
        post("getblock", [hash])
    end
end