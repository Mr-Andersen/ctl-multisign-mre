## Minimal example for CTL

```
Error: ExUnitsEvaluationFailed: Script failures:
- Spend:1
  - Redeemer: (List [(Bytes (hexToByteArrayUnsafe "b797ff6d342d9d1385bcedea9abc985d0244f5f02117160eaac6dc4b")),(Bytes (hexToByteArrayUnsafe "faf13061482764603f22a1ab155052e27051d82da51e5e3ef117c949")),(Bytes (hexToByteArrayUnsafe "7d15cbceacd1ae678dec6e6a4293b81c22d354021a0945210eba129e"))])
  - Input: (TransactionInput { index: 1u, transactionId: (TransactionHash (hexToByteArrayUnsafe "8d1af9bde4377244b731d41594c4b619ed9b6a655a45f799eb9e5176889336ba")) })
  - An error has occurred:  User error:
    The machine terminated because of an error, either from a built-in function or from an explicit use of 'error'.
  - Trace:
    1.  Not enough signatures (0/1): []
    2.  PT5
```

### Run once with Nix (will download&build more than Spago method):

```sh
nix build .#checks.x86_64-linux.ctl-multisign-mre --no-link -L
```

### Run with spago

```sh
nix develop .#offchain
cd offchain
spago run -m Test
```

#### On-chain

If you changed something in on-chain part:

```sh
nix run .#script-exporter -- offchain/src/
```
