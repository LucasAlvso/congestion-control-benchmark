#!/usr/bin/env python3
"""
plot_pcap.py <csv_path> <png_prefix>

Reads a CSV exported by tshark with columns:
  frame.time_relative, tcp.seq, tcp.ack, tcp.len, tcp.analysis.bytes_in_flight

Generates two PNGs:
  <png_prefix>_timeseq.png            -> Time-Sequence graph (seq vs relative time)
  <png_prefix>_bytes_in_flight.png    -> I/O graph (bytes_in_flight vs relative time)

Requirements: pandas, matplotlib
"""
import sys
import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

MIN_SAMPLES = 10  # require at least this many valid samples to plot

def safe_read(csv_path):
    try:
        df = pd.read_csv(csv_path, sep=",", quotechar='"', skipinitialspace=True)
        return df
    except Exception as e:
        print(f"Failed to read CSV {csv_path}: {e}")
        return None

def to_numeric(series):
    return pd.to_numeric(series, errors="coerce")

def plot_time_sequence(df, png_path):
    # Use tcp.seq and tcp.len to show sequence progression
    if "frame.time_relative" not in df.columns or "tcp.seq" not in df.columns:
        print("Required fields for time-sequence missing, skipping.")
        return

    try:
        t = to_numeric(df["frame.time_relative"])
        seq = to_numeric(df["tcp.seq"])
        length = to_numeric(df["tcp.len"]) if "tcp.len" in df.columns else None

        mask = t.notna() & seq.notna()
        if mask.sum() < MIN_SAMPLES:
            print("No valid seq packets to plot time-sequence (insufficient samples).")
            return

        t = t[mask].values
        seq = seq[mask].values
        if length is not None:
            length = length[mask].values
        else:
            length = np.zeros_like(seq)

        # Normalize sequence numbers to start from zero (use first observed seq)
        base = seq[0]
        seq_rel = seq - base

        plt.figure(figsize=(10,4))
        plt.step(t, seq_rel, where="post", label="seq (relative)")
        plt.scatter(t, seq_rel, s=6, color="tab:blue")
        plt.xlabel("Time (s) (relative)")
        plt.ylabel("Sequence number (relative)")
        plt.title("Time-Sequence Graph (relative time)")
        plt.grid(True)
        plt.tight_layout()
        plt.savefig(png_path)
        plt.close()
        print(f"Wrote time-sequence graph: {png_path}")
    except Exception as e:
        print(f"Failed to plot time-sequence for {png_path}: {e}")

def plot_bytes_in_flight(df, png_path):
    if "frame.time_relative" not in df.columns or "tcp.analysis.bytes_in_flight" not in df.columns:
        print("Required fields for bytes_in_flight missing, skipping.")
        return

    try:
        t = to_numeric(df["frame.time_relative"])
        bif = to_numeric(df["tcp.analysis.bytes_in_flight"])

        mask = t.notna() & bif.notna()
        if mask.sum() < MIN_SAMPLES:
            print("No valid bytes_in_flight samples to plot (insufficient samples).")
            return

        t = t[mask].values
        bif = bif[mask].values

        plt.figure(figsize=(10,4))
        # use step to show window evolution
        plt.step(t, bif, where="post", color="tab:green", label="bytes_in_flight")
        plt.xlabel("Time (s) (relative)")
        plt.ylabel("Bytes in flight")
        plt.title("I/O Graph: tcp.analysis.bytes_in_flight")
        plt.grid(True)
        plt.tight_layout()
        plt.savefig(png_path)
        plt.close()
        print(f"Wrote bytes_in_flight graph: {png_path}")
    except Exception as e:
        print(f"Failed to plot bytes_in_flight for {png_path}: {e}")

def main():
    if len(sys.argv) < 3:
        print("Usage: plot_pcap.py <csv_path> <png_prefix>")
        sys.exit(2)

    csv_path = sys.argv[1]
    png_prefix = sys.argv[2]

    if not os.path.exists(csv_path):
        print(f"CSV not found: {csv_path}")
        sys.exit(1)

    df = safe_read(csv_path)
    if df is None:
        sys.exit(1)

    # Normalize header names to expected strings if possible (case-insensitive)
    df_columns_lower = {c.lower(): c for c in df.columns}
    mapping = {}
    for expected in ["frame.time_relative", "tcp.seq", "tcp.ack", "tcp.len", "tcp.analysis.bytes_in_flight"]:
        if expected in df.columns:
            mapping[expected] = expected
        elif expected.lower() in df_columns_lower:
            mapping[expected] = df_columns_lower[expected.lower()]

    if mapping:
        df = df.rename(columns={v: k for k, v in mapping.items()})

    # Plot files
    png_ts = f"{png_prefix}_timeseq.png"
    png_bif = f"{png_prefix}_bytes_in_flight.png"

    # Plot only if enough data; functions handle checks and report reasons for skipping.
    plot_time_sequence(df, png_ts)
    plot_bytes_in_flight(df, png_bif)

if __name__ == "__main__":
    main()
