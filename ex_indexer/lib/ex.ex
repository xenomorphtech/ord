defmodule Ord.Ex do
    use Application

    def start(_type, _args) do
        import Supervisor.Spec, warn: false
    
        supervisor = Supervisor.start_link([
            {DynamicSupervisor, strategy: :one_for_one, name: Ord.Supervisor, max_seconds: 1, max_restarts: 999_999_999_999}
        ], strategy: :one_for_one)
    
        path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/backup"])
        File.mkdir_p!(path)
        path = Path.join([Application.fetch_env!(:ord, :work_folder), "db/main"])
        File.mkdir_p!(path)

        FlatKV.load_table(MainChain, %{path: path, index: [:hash]})
        FlatKV.load_table(Ord, %{path: path, index: [:txid, :txid_current, :blockhash, :blockheight, :owner]})
        FlatKV.load_table(OrdHistory, %{path: path, index: [:txid, :sender, :receiver, :blockheight, :ord]})

        {:ok, _} = DynamicSupervisor.start_child(Ord.Supervisor, %{
            id: Ord.GenIndexer, start: {Ord.GenIndexer, :start_link, []}
        })
    
        supervisor
    end
end

defmodule Snip do
    #btrfs filesystem du db/
    def test() do
        ordi_deploy = "b61b0172d95e266c18aea0c624db987e971a5d6d4ebc2aaed85da4642d635735"
        orid_mint_1 = "24f2585e667e345c7b72a4969b4c70eb0e2106727d876217497c6cf86a8a354c"
        bbb_inscribe = "3034a4627ae6c31b6f4b56078a90f489fd1ec2e9a2a4f2de858fd0d7bde29fab"
        bbb_xfer = "62738a8f6aa7b7f9ae44dc8639752550151bfcc4af52ae4d81b81b999a4b5cf9"
        domo_xfer = "5f6e00ecc71f5fe0d593db2f0e902bded1e15de5d28239e842daa44dbc5fc00f"
        Ord.Block.getrawtransaction(bbb_xfer)
    end
end