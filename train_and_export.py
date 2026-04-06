"""
train_and_export.py
====================
Train a Mini-InceptionNet model on ECG data and export:
  - weights.mem  (padded to 8192 entries)
  - bias.mem     (padded to 128 entries)
  - context.mem  (16 layers matching the full Mini-InceptionNet architecture)

Usage:
    python train_and_export.py

Requires:  numpy, torch (PyTorch)
Output files are written to the directory specified by OUT_DIR (default: current dir).

Layer table (9 conv layers + relu + maxpool):
  Layer  0: CONV  J=7  K=1   N=8   w_base=0     b_base=0
  Layer  1: RELU
  Layer  2: MAXPOOL J=2 stride=2
  Layer  3: CONV  J=1  K=8   N=8   w_base=56    b_base=8
  Layer  4: CONV  J=3  K=8   N=8   w_base=120   b_base=16
  Layer  5: CONV  J=5  K=8   N=8   w_base=312   b_base=24
  Layer  6: CONV  J=1  K=8   N=8   w_base=632   b_base=32
  Layer  7: RELU
  Layer  8: CONV  J=1  K=32  N=16  w_base=696   b_base=40
  Layer  9: CONV  J=3  K=32  N=16  w_base=1208  b_base=56
  Layer 10: CONV  J=5  K=32  N=16  w_base=2744  b_base=72
  Layer 11: CONV  J=1  K=32  N=16  w_base=5304  b_base=88
  Layer 12: RELU
  Layer 13: ADD   residual_source=7
  Layer 14: RELU
  Layer 15: NOP
"""

import os
import struct

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OUT_DIR      = "."
WDEPTH       = 8192    # weight memory depth (entries)
BDEPTH       = 128     # bias memory depth (entries)
DATA_WIDTH   = 16      # bits per weight/bias entry

FIXED_SCALE  = 256     # Q8.8 fixed-point scale factor

# ---------------------------------------------------------------------------
# Bit-field layout helpers
# ---------------------------------------------------------------------------
def make_context_entry(op, J, K, N, Y, stride, w_base, b_base, res):
    """Pack a 64-bit context memory entry."""
    val  = (op     & 0x7)    << 60
    val |= (J      & 0xF)    << 56
    val |= (K      & 0xFF)   << 48
    val |= (N      & 0xFF)   << 40
    val |= (Y      & 0x3FF)  << 30
    val |= (stride & 0x3)    << 28
    val |= (w_base & 0xFFFF) << 12
    val |= (b_base & 0xFF)   << 4
    val |= (res    & 0xF)
    return val

# op_type encoding
OP_CONV    = 0
OP_MAXPOOL = 1
OP_ADD     = 2
OP_RELU    = 3
OP_GAP     = 4
OP_NOP     = 7

# ---------------------------------------------------------------------------
# 16-layer context table
# ---------------------------------------------------------------------------
CONTEXT_LAYERS = [
    # (op,        J, K,   N,  Y,   stride, w_base, b_base, res)
    (OP_CONV,    7, 1,   8,  320,  1,      0,      0,      0),   # Layer  0
    (OP_RELU,    0, 0,   0,  320,  1,      0,      0,      0),   # Layer  1
    (OP_MAXPOOL, 2, 0,   0,  160,  2,      0,      0,      0),   # Layer  2
    (OP_CONV,    1, 8,   8,  160,  1,     56,      8,      0),   # Layer  3
    (OP_CONV,    3, 8,   8,  160,  1,    120,     16,      0),   # Layer  4
    (OP_CONV,    5, 8,   8,  160,  1,    312,     24,      0),   # Layer  5
    (OP_CONV,    1, 8,   8,  160,  1,    632,     32,      0),   # Layer  6
    (OP_RELU,    0, 0,   0,  160,  1,      0,      0,      0),   # Layer  7
    (OP_CONV,    1, 32, 16,  160,  1,    696,     40,      0),   # Layer  8
    (OP_CONV,    3, 32, 16,  160,  1,   1208,     56,      0),   # Layer  9
    (OP_CONV,    5, 32, 16,  160,  1,   2744,     72,      0),   # Layer 10
    (OP_CONV,    1, 32, 16,  160,  1,   5304,     88,      0),   # Layer 11
    (OP_RELU,    0, 0,   0,  160,  1,      0,      0,      0),   # Layer 12
    (OP_ADD,     0, 0,   0,  160,  1,      0,      0,      7),   # Layer 13
    (OP_RELU,    0, 0,   0,  160,  1,      0,      0,      0),   # Layer 14
    (OP_NOP,     0, 0,   0,    0,  0,      0,      0,      0),   # Layer 15
]

# Total weights/biases expected:
#  Layer  0: 7*1*8   = 56 weights,  8 biases
#  Layer  3: 1*8*8   = 64 weights,  8 biases  -> w_base=56,  b_base=8
#  Layer  4: 3*8*8   = 192 weights, 8 biases  -> w_base=120, b_base=16
#  Layer  5: 5*8*8   = 320 weights, 8 biases  -> w_base=312, b_base=24
#  Layer  6: 1*8*8   = 64 weights,  8 biases  -> w_base=632, b_base=32
#  Layer  8: 1*32*16 = 512 weights, 16 biases -> w_base=696, b_base=40
#  Layer  9: 3*32*16 = 1536 weights,16 biases -> w_base=1208,b_base=56
#  Layer 10: 5*32*16 = 2560 weights,16 biases -> w_base=2744,b_base=72
#  Layer 11: 1*32*16 = 512 weights, 16 biases -> w_base=5304,b_base=88
#  Total: 56+64+192+320+64+512+1536+2560+512 = 5816 weights
#         8+8+8+8+8+16+16+16+16             = 104 biases

TOTAL_WEIGHTS = 5816
TOTAL_BIASES  = 104


def float_to_fixed16(val):
    """Convert float to 16-bit signed fixed-point Q8.8, clamped."""
    scaled = int(round(val * FIXED_SCALE))
    scaled = max(-32768, min(32767, scaled))
    # Represent as unsigned 16-bit (two's complement)
    if scaled < 0:
        scaled = scaled + 65536
    return scaled & 0xFFFF


def export_context_mem(path):
    """Write context.mem with 16 entries."""
    with open(path, 'w', encoding='utf-8') as f:
        f.write("// context.mem - 16-layer Mini-InceptionNet configuration\n")
        f.write("// 64-bit entries, 16 hex chars per line\n")
        op_names = {0: 'CONV', 1: 'MAXPOOL', 2: 'ADD', 3: 'RELU', 4: 'GAP', 7: 'NOP'}
        for i, row in enumerate(CONTEXT_LAYERS):
            op, J, K, N, Y, stride, w_base, b_base, res = row
            entry = make_context_entry(*row)
            comment = ("// Layer {:2d}: {:7s} J={} K={} N={} Y={} "
                       "stride={} w_base={} b_base={} res={}").format(
                i, op_names.get(op, str(op)), J, K, N, Y,
                stride, w_base, b_base, res)
            f.write("{}\n{:016X}\n".format(comment, entry))
    print("Written: {}  ({} entries)".format(path, len(CONTEXT_LAYERS)))


def export_weight_mem(path, weights_int):
    """Write weights.mem padded to WDEPTH entries."""
    if len(weights_int) > WDEPTH:
        raise ValueError(
            "Too many weights: {} > {}".format(len(weights_int), WDEPTH))
    with open(path, 'w', encoding='utf-8') as f:
        for w in weights_int:
            f.write("{:04X}\n".format(w & 0xFFFF))
        # Pad to WDEPTH
        for _ in range(WDEPTH - len(weights_int)):
            f.write("0000\n")
    print("Written: {}  ({} data + {} padding = {} total)".format(
        path, len(weights_int), WDEPTH - len(weights_int), WDEPTH))


def export_bias_mem(path, biases_int):
    """Write bias.mem padded to BDEPTH entries."""
    if len(biases_int) > BDEPTH:
        raise ValueError(
            "Too many biases: {} > {}".format(len(biases_int), BDEPTH))
    with open(path, 'w', encoding='utf-8') as f:
        for b in biases_int:
            f.write("{:04X}\n".format(b & 0xFFFF))
        for _ in range(BDEPTH - len(biases_int)):
            f.write("0000\n")
    print("Written: {}  ({} data + {} padding = {} total)".format(
        path, len(biases_int), BDEPTH - len(biases_int), BDEPTH))


def generate_dummy_weights():
    """
    Generate dummy (unity / small) weights for simulation testing.
    Replace this function with trained model weight extraction.

    Weight order for each CONV layer: [n][k][j]
      for n in range(N):
        for k in range(K):
          for j in range(J):
            weights.append(w[n][k][j])

    Bias order: b[n] for n in range(N).
    """
    import math

    conv_layers = [
        # (J, K, N)
        (7, 1,  8),   # Layer 0
        (1, 8,  8),   # Layer 3
        (3, 8,  8),   # Layer 4
        (5, 8,  8),   # Layer 5
        (1, 8,  8),   # Layer 6
        (1, 32, 16),  # Layer 8
        (3, 32, 16),  # Layer 9
        (5, 32, 16),  # Layer 10
        (1, 32, 16),  # Layer 11
    ]

    weights_float = []
    biases_float  = []

    for layer_idx, (J, K, N) in enumerate(conv_layers):
        # Simple initialization: small Gaussian-like values scaled by 1/sqrt(K*J)
        scale = 1.0 / math.sqrt(K * J)
        for n in range(N):
            for k in range(K):
                for j in range(J):
                    # Deterministic pseudo-random based on indices
                    seed_val = (layer_idx * 1000 + n * 100 + k * 10 + j)
                    # Simple hash -> float in [-1, 1]
                    w = math.sin(seed_val * 0.7) * scale
                    weights_float.append(w)
        for n in range(N):
            b = math.cos(n * 0.3 + layer_idx) * 0.1
            biases_float.append(b)

    return weights_float, biases_float


def main():
    print("=" * 60)
    print("train_and_export.py - Mini-InceptionNet Weight Exporter")
    print("=" * 60)

    # --- Generate or load weights ----------------------------------------
    # Replace generate_dummy_weights() with your trained model extraction.
    print("\nGenerating weights and biases (dummy values for simulation)...")
    weights_float, biases_float = generate_dummy_weights()

    print("  Total weights: {}  (expected {})".format(
        len(weights_float), TOTAL_WEIGHTS))
    print("  Total biases:  {}  (expected {})".format(
        len(biases_float), TOTAL_BIASES))

    if len(weights_float) != TOTAL_WEIGHTS:
        print("WARNING: weight count mismatch")
    if len(biases_float) != TOTAL_BIASES:
        print("WARNING: bias count mismatch")

    # --- Convert to fixed-point ------------------------------------------
    weights_int = [float_to_fixed16(w) for w in weights_float]
    biases_int  = [float_to_fixed16(b) for b in biases_float]

    # --- Export -----------------------------------------------------------
    print()
    export_context_mem(os.path.join(OUT_DIR, "context.mem"))
    export_weight_mem(os.path.join(OUT_DIR, "weights.mem"), weights_int)
    export_bias_mem(os.path.join(OUT_DIR, "bias.mem"),     biases_int)

    print("\nDone. Files written to: {}".format(os.path.abspath(OUT_DIR)))
    print("Copy these .mem files to your Vivado simulation working directory.")


if __name__ == "__main__":
    main()
