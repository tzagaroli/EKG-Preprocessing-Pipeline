"""
ECG segment reviewer (Tinder-style) for output_path/pcb/*.csv

- Enter output_path in the GUI.
- Loads CSVs in output_path/pcb named like "1.csv", "2.csv", ...
- Displays V5 with colored intervals and peak markers based on columns:
    P-wave, P-peak, QRS-complex, R-peak, T-wave, T-peak
  Assumes those columns are per-sample masks (0/1) or generally "nonzero means active".
- Buttons:
    Keep  -> keep file
    Reject -> move file to output_path/pcb/_rejected/
- When all files reviewed:
    Renumbers kept CSVs sequentially 1.csv..N.csv (no holes), preserving order.

Requirements:
    pip install pandas matplotlib
Tkinter is part of standard Python on most installs.
"""

import os
import re
import shutil
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

import pandas as pd
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure


NUMERIC_CSV_RE = re.compile(r"^(\d+)\.csv$", re.IGNORECASE)

INTERVAL_COLORS = {
    "P-wave": "tab:blue",
    "QRS-complex": "tab:orange",
    "T-wave": "tab:green",
}

PEAK_COLORS = {
    "P-peak": "tab:blue",
    "R-peak": "tab:red",
    "T-peak": "tab:green",
}


def is_numeric_csv(filename: str) -> bool:
    return NUMERIC_CSV_RE.match(filename) is not None


def numeric_id(filename: str) -> int:
    m = NUMERIC_CSV_RE.match(filename)
    if not m:
        raise ValueError(f"Not a numeric csv filename: {filename}")
    return int(m.group(1))


def contiguous_runs(mask):
    """
    Convert boolean mask to list of (start_index, end_index) inclusive runs.
    """
    runs = []
    in_run = False
    start = 0
    for i, v in enumerate(mask):
        if v and not in_run:
            in_run = True
            start = i
        elif not v and in_run:
            runs.append((start, i - 1))
            in_run = False
    if in_run:
        runs.append((start, len(mask) - 1))
    return runs


def safe_mkdir(path: str):
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)


def renumber_kept_csvs(pcb_dir: str):
    """
    Renumber kept numeric CSV files in pcb_dir to 1..N without gaps,
    preserving numeric order based on original filenames.

    Uses a two-phase rename to avoid overwrites:
      1) rename to temporary names __tmp__<id>.csv
      2) rename temp names to 1.csv..N.csv
    """
    all_files = [f for f in os.listdir(pcb_dir) if is_numeric_csv(f)]
    if not all_files:
        return 0

    all_files.sort(key=numeric_id)
    tmp_map = []
    # Phase 1: numeric -> tmp
    for f in all_files:
        old_path = os.path.join(pcb_dir, f)
        old_id = numeric_id(f)
        tmp_name = f"__tmp__{old_id}.csv"
        tmp_path = os.path.join(pcb_dir, tmp_name)
        os.replace(old_path, tmp_path)
        tmp_map.append(tmp_name)

    # Phase 2: tmp -> 1..N
    for new_id, tmp_name in enumerate(sorted(tmp_map, key=lambda x: int(re.findall(r"\d+", x)[0])), start=1):
        tmp_path = os.path.join(pcb_dir, tmp_name)
        new_path = os.path.join(pcb_dir, f"{new_id}.csv")
        os.replace(tmp_path, new_path)

    return len(all_files)


class ECGReviewerApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("ECG Segment Reviewer")

        self.output_path_var = tk.StringVar()
        self.status_var = tk.StringVar(value="Select an output_path and press Load.")

        self.pcb_dir = None
        self.files = []
        self.index = 0

        self._build_ui()
        self._build_plot()

    def _build_ui(self):
        pad = {"padx": 8, "pady": 6}

        top = ttk.Frame(self.root)
        top.pack(fill="x", **pad)

        ttk.Label(top, text="output_path:").pack(side="left")
        self.path_entry = ttk.Entry(top, textvariable=self.output_path_var, width=60)
        self.path_entry.pack(side="left", padx=6)

        ttk.Button(top, text="Browse", command=self.on_browse).pack(side="left", padx=4)
        ttk.Button(top, text="Load", command=self.on_load).pack(side="left", padx=4)

        mid = ttk.Frame(self.root)
        mid.pack(fill="both", expand=True, **pad)

        self.plot_frame = ttk.Frame(mid)
        self.plot_frame.pack(fill="both", expand=True)

        bottom = ttk.Frame(self.root)
        bottom.pack(fill="x", **pad)

        self.reject_btn = ttk.Button(bottom, text="Reject (←)", command=self.on_reject, state="disabled")
        self.reject_btn.pack(side="left", padx=4)

        self.keep_btn = ttk.Button(bottom, text="Keep (→)", command=self.on_keep, state="disabled")
        self.keep_btn.pack(side="left", padx=4)

        ttk.Label(bottom, textvariable=self.status_var).pack(side="right")

        # Keyboard shortcuts
        self.root.bind("<Right>", lambda e: self.on_keep())
        self.root.bind("<Left>", lambda e: self.on_reject())

    def _build_plot(self):
        self.fig = Figure(figsize=(9, 4.8), dpi=100)
        self.ax = self.fig.add_subplot(111)
        self.ax.set_title("No data loaded")
        self.ax.set_xlabel("Sample index")
        self.ax.set_ylabel("V5")

        self.canvas = FigureCanvasTkAgg(self.fig, master=self.plot_frame)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        self.canvas.draw()

    def on_browse(self):
        path = filedialog.askdirectory(title="Select output_path")
        if path:
            self.output_path_var.set(path)

    def on_load(self):
        output_path = self.output_path_var.get().strip()
        if not output_path:
            messagebox.showerror("Error", "Please enter an output_path.")
            return

        pcb_dir = os.path.join(output_path, "pcb")
        if not os.path.isdir(pcb_dir):
            messagebox.showerror("Error", f"Folder not found: {pcb_dir}\nExpected output_path/pcb/")
            return

        files = [f for f in os.listdir(pcb_dir) if is_numeric_csv(f)]
        files.sort(key=numeric_id)

        if not files:
            messagebox.showwarning("No files", f"No numeric CSV files found in: {pcb_dir}")
            return

        self.pcb_dir = pcb_dir
        self.files = files
        self.index = 0

        self.keep_btn.config(state="normal")
        self.reject_btn.config(state="normal")

        self._show_current()

    def _current_path(self):
        if self.index < 0 or self.index >= len(self.files):
            return None
        return os.path.join(self.pcb_dir, self.files[self.index])

    def _show_current(self):
        path = self._current_path()
        if path is None:
            self._finish_review()
            return

        try:
            df = pd.read_csv(path)
        except Exception as e:
            self._plot_error(f"Failed to read {os.path.basename(path)}: {e}")
            self.status_var.set(f"{self.index+1}/{len(self.files)}  (read error)")
            return

        self._plot_df(df, title=os.path.basename(path))
        self.status_var.set(f"{self.index+1}/{len(self.files)}  |  {os.path.basename(path)}")

    def _plot_error(self, msg: str):
        self.ax.clear()
        self.ax.set_title("Error")
        self.ax.text(0.5, 0.5, msg, ha="center", va="center", wrap=True, transform=self.ax.transAxes)
        self.canvas.draw()

    def _plot_df(self, df: pd.DataFrame, title: str):
        required = ["V5", "P-wave", "P-peak", "QRS-complex", "R-peak", "T-wave", "T-peak"]
        missing = [c for c in required if c not in df.columns]
        if missing:
            self._plot_error(f"Missing columns: {missing}")
            return

        y = df["V5"].to_numpy()
        x = range(len(y))

        self.ax.clear()
        self.ax.plot(x, y, linewidth=1.0)
        self.ax.set_title(title)
        self.ax.set_xlabel("Sample index")
        self.ax.set_ylabel("V5")

        # Interval highlighting: shade contiguous runs where column is nonzero
        for col, color in INTERVAL_COLORS.items():
            mask = (df[col].fillna(0).to_numpy() != 0)
            for (a, b) in contiguous_runs(mask):
                self.ax.axvspan(a, b, alpha=0.15, color=color, label=col)

        # Peak markers: scatter points where peak columns are nonzero
        for col, color in PEAK_COLORS.items():
            mask = (df[col].fillna(0).to_numpy() != 0)
            idx = [i for i, v in enumerate(mask) if v]
            if idx:
                self.ax.scatter(idx, [y[i] for i in idx], s=28, color=color, label=col)

        # Deduplicate legend entries
        handles, labels = self.ax.get_legend_handles_labels()
        seen = set()
        uniq_h, uniq_l = [], []
        for h, l in zip(handles, labels):
            if l not in seen:
                seen.add(l)
                uniq_h.append(h)
                uniq_l.append(l)
        if uniq_l:
            self.ax.legend(uniq_h, uniq_l, loc="upper right", fontsize=9)

        self.ax.grid(True, alpha=0.3)
        self.canvas.draw()

    def on_keep(self):
        if self._current_path() is None:
            return
        self.index += 1
        self._show_current()

    def on_reject(self):
        path = self._current_path()
        if path is None:
            return

        safe_mkdir(os.path.join(self.pcb_dir, "_rejected"))
        dst = os.path.join(self.pcb_dir, "_rejected", os.path.basename(path))

        try:
            os.replace(path, dst)  # move atomically when possible
        except Exception:
            # fallback
            shutil.move(path, dst)

        # Remove from list without advancing index (next file shifts into current index)
        del self.files[self.index]

        if self.index >= len(self.files):
            self._finish_review()
        else:
            self._show_current()

    def _finish_review(self):
        # Disable buttons during renumber
        self.keep_btn.config(state="disabled")
        self.reject_btn.config(state="disabled")

        if not self.pcb_dir:
            self._plot_error("Nothing to renumber.")
            return

        try:
            n = renumber_kept_csvs(self.pcb_dir)
        except Exception as e:
            self._plot_error(f"Renumbering failed: {e}")
            self.status_var.set("Renumbering failed")
            return

        self.ax.clear()
        self.ax.set_title("Done")
        self.ax.text(
            0.5, 0.5,
            f"Review complete.\nKept files renumbered: 1.csv .. {n}.csv\nRejected moved to pcb/_rejected/",
            ha="center", va="center", transform=self.ax.transAxes
        )
        self.canvas.draw()

        self.status_var.set(f"Done. Kept={n}, Rejected in _rejected/.")


def main():
    root = tk.Tk()
    app = ECGReviewerApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
