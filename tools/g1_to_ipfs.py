#!/usr/bin/env python3
"""
Convert Duniter G1 Public Key to IPFS PeerID

The G1 public key is a base58-encoded ed25519 public key.
This script adds the IPFS multihash prefix and re-encodes as PeerID.

Usage:
    ./g1_to_ipfs.py DsEx1pSxxxxxx

Example:
    $ ./g1_to_ipfs.py DsEx1pS33RHBH9vJnQ7A2GXZPF3CptdKLPa8RYx2f6BUJD
    12D3KooWL2FcDJ41U9SyLuvDmA5qGzyoaj2RoEHiJPpCvY8jvx9u

License: AGPL-3.0
"""

import sys
import base58
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

def g1_to_ipfs(g1_pubkey: str) -> str:
    """
    Convert G1 public key to IPFS PeerID.
    
    G1 format:
        - Base58-encoded raw ed25519 public key (32 bytes)
    
    IPFS PeerID format (for ed25519):
        - Multihash prefix: 0x00 0x24 0x08 0x01 0x12 0x20 (6 bytes)
        - Raw ed25519 public key: 32 bytes
    """
    # Decode base58 G1 key
    raw_pubkey = base58.b58decode(g1_pubkey)
    
    # Validate it's a valid ed25519 public key
    pubkey = ed25519.Ed25519PublicKey.from_public_bytes(raw_pubkey)
    
    # Get raw bytes (should be same as decoded)
    raw_bytes = pubkey.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )
    
    # Add IPFS multihash prefix for ed25519
    # 0x00 = identity multihash
    # 0x24 = length (36 bytes total)
    # 0x08 0x01 = protobuf key type (ed25519)
    # 0x12 0x20 = protobuf public key field + length (32 bytes)
    IPFS_ED25519_PREFIX = b'\x00\x24\x08\x01\x12\x20'
    
    # Encode as base58
    peer_id = base58.b58encode(IPFS_ED25519_PREFIX + raw_bytes).decode('ascii')
    
    return peer_id

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <G1_PUBLIC_KEY>", file=sys.stderr)
        sys.exit(1)
    
    g1_key = sys.argv[1]
    
    try:
        peer_id = g1_to_ipfs(g1_key)
        print(peer_id)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
