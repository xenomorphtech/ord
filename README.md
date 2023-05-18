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
./ex_indexer/ordd
```
