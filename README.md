# ord
Ordinal, BRC-20 indexer and potentially more

## Setup

Fully synced node with hardcoded `user:pass` for now.

```
txindex=1
rpcuser=ord
rpcpassword=ord
```

## Building

Use podman or docker (autodetected).

```
cd ex_indexer/
sh build.sh
```

## Running

```
WORKFOLDER = Database+Config directory (default "~/.cache/ord/")
RPCAUTH = node rpc user:pass (default ord:ord)
RPCPORT = node rpc port (default 8332)

FIRST_INSCRIPTION_HEIGHT = Block to start indexing from (default 767430)

./ex_indexer/ordd
```
