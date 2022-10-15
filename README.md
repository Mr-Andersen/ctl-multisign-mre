## Minimal example for CTL

```
Error: `submit` call failed. Error from Ogmios: [{"validationTagMismatch":null}]
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
