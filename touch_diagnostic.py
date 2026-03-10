#!/usr/bin/env python3
"""
Touch Diagnostic Tool for Tinta4Plus-Universal

Shows targets at specific positions on the eInk display (2560x1600).
Tap each target and the script records the actual touch position,
then reports the offset (expected vs actual) for each point.

Run this WHILE IN EINK MODE to test touchscreen mapping accuracy.

Usage: python3 touch_diagnostic.py
"""

import tkinter as tk
import sys
import time

# eInk display resolution
SCREEN_W = 2560
SCREEN_H = 1600

# Target positions: (label, x_fraction, y_fraction)
TARGETS = [
    ("Top-Left",      0.10, 0.10),
    ("Top-Center",    0.50, 0.10),
    ("Top-Right",     0.90, 0.10),
    ("Center-Left",   0.10, 0.50),
    ("Center",        0.50, 0.50),
    ("Center-Right",  0.90, 0.50),
    ("Bottom-Left",   0.10, 0.90),
    ("Bottom-Center", 0.50, 0.90),
    ("Bottom-Right",  0.90, 0.90),
]

TARGET_RADIUS = 30
RESULTS = []


class TouchDiagnostic:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Touch Diagnostic")
        self.root.attributes('-fullscreen', True)
        self.root.configure(bg='white')

        self.canvas = tk.Canvas(self.root, bg='white', highlightthickness=0,
                                cursor='crosshair')
        self.canvas.pack(fill=tk.BOTH, expand=True)

        self.current_target = 0
        self.results = []
        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()

        # Bind touch/click
        self.canvas.bind('<Button-1>', self.on_tap)
        self.root.bind('<Escape>', lambda e: self.finish())

        # Status text
        self.status_text = self.canvas.create_text(
            self.screen_w // 2, 40,
            text="Touch Diagnostic — Tap each target crosshair",
            font=('sans-serif', 20, 'bold'), fill='black'
        )
        self.instruction_text = self.canvas.create_text(
            self.screen_w // 2, 75,
            text=f"Screen detected: {self.screen_w}x{self.screen_h} | Press ESC to quit",
            font=('sans-serif', 14), fill='gray40'
        )

        # Draw first target
        self.root.after(100, self.show_target)

    def show_target(self):
        if self.current_target >= len(TARGETS):
            self.show_results()
            return

        self.canvas.delete('target')
        self.canvas.delete('targetlabel')

        label, xf, yf = TARGETS[self.current_target]
        tx = int(xf * self.screen_w)
        ty = int(yf * self.screen_h)

        r = TARGET_RADIUS
        # Crosshair
        self.canvas.create_line(tx - r, ty, tx + r, ty, fill='red', width=3, tags='target')
        self.canvas.create_line(tx, ty - r, tx, ty + r, fill='red', width=3, tags='target')
        self.canvas.create_oval(tx - r, ty - r, tx + r, ty + r,
                                outline='red', width=2, tags='target')

        # Label
        self.canvas.create_text(
            tx, ty - r - 15,
            text=f"[{self.current_target + 1}/{len(TARGETS)}] {label}",
            font=('sans-serif', 16, 'bold'), fill='red', tags='targetlabel'
        )

        # Update status
        self.canvas.itemconfig(self.status_text,
                               text=f"Tap the crosshair: {label} ({self.current_target + 1}/{len(TARGETS)})")

    def on_tap(self, event):
        if self.current_target >= len(TARGETS):
            return

        label, xf, yf = TARGETS[self.current_target]
        expected_x = int(xf * self.screen_w)
        expected_y = int(yf * self.screen_h)
        actual_x = event.x
        actual_y = event.y

        dx = actual_x - expected_x
        dy = actual_y - expected_y
        dist = (dx**2 + dy**2) ** 0.5

        self.results.append({
            'label': label,
            'expected': (expected_x, expected_y),
            'actual': (actual_x, actual_y),
            'offset': (dx, dy),
            'distance': dist
        })

        # Show tap marker
        self.canvas.create_oval(actual_x - 5, actual_y - 5,
                                actual_x + 5, actual_y + 5,
                                fill='blue', outline='blue', tags='target')

        self.current_target += 1
        self.root.after(400, self.show_target)

    def show_results(self):
        self.canvas.delete('target')
        self.canvas.delete('targetlabel')

        self.canvas.itemconfig(self.status_text, text="Results — Touch Accuracy Report")
        self.canvas.itemconfig(self.instruction_text,
                               text="Press ESC to quit or close the window")

        y = 120
        header = f"{'Target':<18} {'Expected':>14} {'Actual':>14} {'Offset':>14} {'Distance':>10}"
        self.canvas.create_text(self.screen_w // 2, y, text=header,
                                font=('monospace', 14, 'bold'), fill='black', anchor='n')
        y += 30
        self.canvas.create_line(self.screen_w // 2 - 400, y,
                                self.screen_w // 2 + 400, y, fill='gray')
        y += 15

        total_dist = 0
        max_dist = 0
        for r in self.results:
            ex, ey = r['expected']
            ax, ay = r['actual']
            dx, dy = r['offset']
            d = r['distance']
            total_dist += d
            max_dist = max(max_dist, d)

            color = 'green' if d < 20 else ('orange' if d < 50 else 'red')
            line = (f"{r['label']:<18} ({ex:>4},{ey:>4})   ({ax:>4},{ay:>4})   "
                    f"({dx:>+4},{dy:>+4})   {d:>7.1f}px")
            self.canvas.create_text(self.screen_w // 2, y, text=line,
                                    font=('monospace', 13), fill=color, anchor='n')
            y += 25

        avg_dist = total_dist / len(self.results) if self.results else 0

        y += 15
        self.canvas.create_line(self.screen_w // 2 - 400, y,
                                self.screen_w // 2 + 400, y, fill='gray')
        y += 20
        summary = f"Average offset: {avg_dist:.1f}px | Max offset: {max_dist:.1f}px"
        color = 'green' if avg_dist < 20 else ('orange' if avg_dist < 50 else 'red')
        self.canvas.create_text(self.screen_w // 2, y, text=summary,
                                font=('sans-serif', 16, 'bold'), fill=color, anchor='n')
        y += 35

        if avg_dist < 20:
            verdict = "Touchscreen mapping looks accurate!"
        elif avg_dist < 50:
            verdict = "Minor offset detected — mapping may need calibration."
        else:
            verdict = "Significant offset — touchscreen mapping is likely incorrect."
        self.canvas.create_text(self.screen_w // 2, y, text=verdict,
                                font=('sans-serif', 14), fill=color, anchor='n')

        # Also print to console
        print("\n=== Touch Diagnostic Results ===")
        print(f"Screen: {self.screen_w}x{self.screen_h}")
        print(f"{'Target':<18} {'Expected':>14} {'Actual':>14} {'Offset':>14} {'Dist':>8}")
        print("-" * 72)
        for r in self.results:
            ex, ey = r['expected']
            ax, ay = r['actual']
            dx, dy = r['offset']
            print(f"{r['label']:<18} ({ex:>4},{ey:>4})   ({ax:>4},{ay:>4})   "
                  f"({dx:>+4},{dy:>+4})   {r['distance']:>6.1f}px")
        print("-" * 72)
        print(f"Average: {avg_dist:.1f}px | Max: {max_dist:.1f}px")
        print(f"Verdict: {verdict}")

    def finish(self):
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == '__main__':
    app = TouchDiagnostic()
    app.run()
