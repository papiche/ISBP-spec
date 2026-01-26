#!/usr/bin/env python3
"""
Convert IPFS PeerID to Duniter G1 Public Key

The IPFS PeerID is a multihash-encoded ed25519 public key.
This script extracts the raw key and re-encodes it as base58 (G1 format).

Usage:
    ./ipfs_to_g1.py 12D3KooWxxxxxx

Example:
    $ ./ipfs_to_g1.py 12D3KooWL2FcDJ41U9SyLuvDmA5qGzyoaj2RoEHiJPpCvY8jvx9u
    DsEx1pS33RHBH9vJnQ7A2GXZPF3CptdKLPa8RYx2f6BUJD

License: AGPL-3.0
"""

import sys
import base58

def ipfs_to_g1(peer_id: str) -> str:
    """
    Convert IPFS PeerID to G1 public key.
    
    IPFS PeerID format (for ed25519):
        - Multihash prefix: 0x00 0x24 0x08 0x01 0x12 0x20 (6 bytes)
        - Raw ed25519 public key: 32 bytes
    
    G1 format:
        - Base58-encoded raw ed25519 public key
    """
    # Decode base58 PeerID
    decoded = base58.b58decode(peer_id)
    
    # Remove 6-byte multihash prefix
    raw_pubkey = decoded[6:]
    
    # Re-encode as base58 (G1 format)
    g1_pubkey = base58.b58encode(raw_pubkey).decode()
    
    return g1_pubkey

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <IPFS_PEER_ID>", file=sys.stderr)
        sys.exit(1)
    
    peer_id = sys.argv[1]
    
    try:
        g1_key = ipfs_to_g1(peer_id)
        print(g1_key)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
