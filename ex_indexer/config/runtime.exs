import Config

#System
work_folder = (System.get_env("WORKFOLDER") || Path.expand("~/.cache/ord/"))
config :ord, :work_folder, work_folder
config :ord, :log_level, (System.get_env("LOG_LEVEL") || "1") |> :erlang.binary_to_integer()
config :ord, :rpcauth, (System.get_env("RPCAUTH") || "ord:ord") |> Base.encode64()
config :ord, :rpcport, (System.get_env("RPCPORT") || "8332") |> :erlang.binary_to_integer()

#make dirs
:ok = File.mkdir_p!(work_folder)

#load env
Envvar.load(Path.join([work_folder, ".env"]))

#Bind Interaces
config :ord, :http_ip4, ((System.get_env("HTTP_IP4") || "0.0.0.0") |> :unicode.characters_to_list() |> :inet.parse_ipv4_address() |> (case do {:ok, addr}-> addr end))
config :ord, :http_ip6, ((System.get_env("HTTP_IP6") || "::1") |> :unicode.characters_to_list() |> :inet.parse_ipv6_address() |> (case do {:ok, addr}-> addr end))
config :ord, :http_port, (System.get_env("HTTP_PORT") || "80") |> :erlang.binary_to_integer()

#bitcoin mainnet
#first brc20 779832
_ord = """
  pub(crate) fn first_inscription_height(self) -> u64 {
    match self {
      Self::Mainnet => 767430,
      Self::Regtest => 0,
      Self::Signet => 112402,
      Self::Testnet => 2413343,
    }
  }
"""
config :ord, :first_inscription_height, (System.get_env("FIRST_INSCRIPTION_HEIGHT") || "767430") |> :erlang.binary_to_integer()
