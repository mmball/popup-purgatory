#!/usr/bin/env python3
"""Drive the game with an external policy: a heuristic, or a Claude model.

The game runs headless with `--policy=external` and, about once per game second,
writes runs/policy/state_<seq>.json (game state + legal moves). This driver
answers with move_<seq>.json {"move": "<id>"}. The game blocks while it waits,
and with --fixed-fps game time pauses, so a slow policy costs wall-clock, not
game balance.

Usage:
  tools/policy_driver.py GODOT --backend heuristic [--runs N] [--seed S] [--max-wave W]
  tools/policy_driver.py GODOT --backend claude    [--model claude-opus-5-5] [--effort low] ...

Backends:
  heuristic  pure Python: completes cheap pop-ups, dismisses old ones when RAM is
             tight, buys huts early then a dojo; a reference opponent for the LLM
  claude     asks Claude for every decision via the Anthropic SDK (pip install
             anthropic; credentials from ANTHROPIC_API_KEY or `ant auth login`).
             Each decision is one request with structured JSON output; a 3-wave
             run is roughly 100-150 requests. Decisions and the model's reasons
             are logged to runs/policy/decisions.jsonl for review.

Run rows still go to runs/external_<seed>.jsonl via the bot's --jsonl.
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import time

POLICY_DIR = "runs/policy"

SYSTEM_PROMPT = """You are playing Popup Purgatory, a Windows-98 desktop roguelite, through a text interface.
Each turn you get the game state as JSON and a list of legal moves. Reply with the id of exactly one move.

How the game works:
- Pop-ups keep appearing. Each open pop-up occupies RAM (ram_used). If ram_used exceeds ram_max for 3 seconds the machine crashes and the run ends. Survival is the first priority.
- Closing a pop-up pays bytes. "dismiss" (clicking the X) pays little; "complete" (doing what the pop-up asks) pays several times more but only some pop-ups can be completed in one click (cheap_complete=true).
- Some pop-ups punish neglect: timeout_kind "multiply" clones the pop-up when age_since_timeout reaches lifetime; "spawn" spawns errors; "escalate" raises its RAM cost. Close those before they time out.
- Targeted challenges: a pop-up with dismiss_spawns>0 (cookie banner) spawns that many more if you dismiss it, so complete it instead. imp_proof pop-ups (Live Chat) dodge imps unless you own a Help Desk. leak pop-ups grow their RAM cost every few seconds until completed; dismissing pays nothing.
- The run is one workday of 8 waves; survive wave 8 and you clock out (a win). After that, overtime is endless.
- Bytes buy buildings. Imp Huts hire imps who walk to pop-ups and dismiss them for you; an Imp Dojo trains two imps from huts within 2 cells to complete instead; RAM Sticks raise ram_max; Coffee Carts speed imps from huts within 2 cells; nothing spawns within 3 cells of a Firewall; the Antivirus Shrine stops timeouts from multiplying; the Pointer Shrine pays +1 per pop-up you close yourself. Building prices rise with each copy. The bot places each building where its radius helps most.
- A "sell" move demolishes one of your buildings for a refund (half its price, three quarters during a break); owned_buildings lists what you have.
- Between waves you pick one of three upgrades.
- Spending bytes never lowers your score (score = total bytes earned), so build whenever it helps.
Strategy hints: keep ram_used comfortably under ram_max; prefer complete over dismiss when RAM is safe; buy huts early; when nothing is urgent, choose "wait"."""

MOVE_SCHEMA = {
    "type": "object",
    "properties": {
        "move": {"type": "string", "description": "the id of one legal move, copied exactly"},
        "reason": {"type": "string", "description": "one short sentence"},
    },
    "required": ["move", "reason"],
    "additionalProperties": False,
}


# ---------- backends ----------

def heuristic(state):
    # "sell:x,y" moves are legal but the heuristic never sells; it only ever
    # picks the ids it names below, so they are dropped here to keep that explicit.
    moves = {m["id"]: m for m in state["legal_moves"] if m["kind"] != "sell"}
    if state["in_break"]:
        picks = [m for m in state["legal_moves"] if m["kind"] == "pick_upgrade"]
        order = ["more_ram", "free_imp", "quick_hands", "complete_bonus", "fast_imps", "spawn_slower", "lean_popups",
                 "antivirus_patch", "dismiss_bonus", "click_bonus", "bigger_x", "bytes_now"]
        for want in order:
            for m in picks:
                if m["upgrade"] == want:
                    return m["id"], f"upgrade priority {want}"
        return picks[0]["id"], "first upgrade"
    pressure = state["ram_used"] / max(1, state["ram_max"])
    popups = state["popups"]
    # 1. anything about to multiply or escalate
    urgent = [p for p in popups if p["lifetime"] > 0 and p["timeout_kind"] != "none" and p["lifetime"] - p["age_since_timeout"] < 4.0]
    for p in sorted(urgent, key=lambda p: p["lifetime"] - p["age_since_timeout"]):
        mid = f"complete:{p['id']}" if p["cheap_complete"] else f"dismiss:{p['id']}"
        if mid in moves:
            return mid, "about to time out"
    # 1b. leaks grow: complete them while they are cheap
    for p in sorted(popups, key=lambda p: -p["ram_cost"]):
        if p.get("leak") and f"complete:{p['id']}" in moves:
            return f"complete:{p['id']}", "leak growing"
    # 2. RAM pressure: dismiss the costliest (never a cookie banner: X-ing it spawns more)
    if pressure > 0.7 and popups:
        for p in sorted(popups, key=lambda p: -p["ram_cost"]):
            mid = f"dismiss:{p['id']}"
            if mid in moves and not p.get("dismiss_spawns"):
                return mid, f"ram pressure {pressure:.2f}"
    # 3. cheap completions, oldest first
    for p in sorted(popups, key=lambda p: -p["age"]):
        mid = f"complete:{p['id']}"
        if mid in moves:
            return mid, "cheap complete"
    # 4. build: huts until 3, then dojo, then ram, then more huts
    b = state["buildings"]
    for want in (["hut"] * 3 + ["dojo", "ram", "hut", "coffee", "hut", "antivirus", "hut"]):
        if want == "hut" and b.get("hut", 0) >= 3 and b.get("dojo", 0) == 0 and "build:dojo" in moves:
            return "build:dojo", "dojo before more huts"
        if f"build:{want}" in moves and (want != "hut" or b.get("hut", 0) < 3 or b.get("dojo", 0) > 0):
            return f"build:{want}", f"build {want}"
    # 5. dismiss the oldest if the desk is crowded (cookies excepted)
    if len(popups) >= 3:
        for p in sorted(popups, key=lambda p: -p["age"]):
            mid = f"dismiss:{p['id']}"
            if mid in moves and not p.get("dismiss_spawns"):
                return mid, "crowded"
    return "wait", "nothing urgent"


class ClaudeBackend:
    def __init__(self, model, effort):
        try:
            import anthropic  # noqa: F401
        except ImportError:
            sys.exit("the claude backend needs the Anthropic SDK: pip install anthropic")
        import anthropic
        self.anthropic = anthropic
        self.client = anthropic.Anthropic()
        self.model = model
        self.effort = effort
        self.history = []  # short memory of (seq, move, reason) for continuity

    def __call__(self, state):
        recent = "\n".join(f"- t={s}: {m} ({r})" for s, m, r in self.history[-6:]) or "(none yet)"
        user = ("Recent decisions:\n" + recent + "\n\nState:\n" + json.dumps(state, separators=(",", ":"))
                + "\n\nChoose one legal move id.")
        try:
            response = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                output_config={"effort": self.effort, "format": {"type": "json_schema", "schema": MOVE_SCHEMA}},
                messages=[{"role": "user", "content": user}],
            )
        except self.anthropic.RateLimitError as e:
            wait = int(e.response.headers.get("retry-after", "20"))
            print(f"rate limited; sleeping {wait}s", file=sys.stderr)
            time.sleep(wait)
            return "wait", "rate limited"
        except self.anthropic.APIStatusError as e:
            print(f"api error {e.status_code}: {e.message}", file=sys.stderr)
            return "wait", "api error"
        except self.anthropic.APIConnectionError:
            print("network error", file=sys.stderr)
            return "wait", "network error"
        if response.stop_reason == "refusal":
            return "wait", "refused"
        text = next((b.text for b in response.content if b.type == "text"), "{}")
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            return "wait", "unparseable reply"
        legal = {m["id"] for m in state["legal_moves"]}
        move = data.get("move", "wait")
        if move not in legal:
            return "wait", f"illegal move {move!r} proposed"
        self.history.append((state["t"], move, data.get("reason", "")))
        return move, data.get("reason", "")


# ---------- protocol loop ----------

def serve(godot, backend, runs, seed, max_wave, decision_interval, log_path, unlock_all=False):
    os.makedirs(POLICY_DIR, exist_ok=True)
    for f in glob.glob(os.path.join(POLICY_DIR, "*.json")):
        os.remove(f)
    out = f"runs/external_{seed}.jsonl"
    args = [godot, "--headless", "--fixed-fps", "60", "--path", ".", "--quit-after", str(runs * max_wave * 60 * 120),
            "--", "--screen=desktop", "--autoplay=1", "--policy=external", f"--policy-dir={POLICY_DIR}",
            f"--decision-interval={decision_interval}", f"--runs={runs}", f"--seed={seed}",
            f"--max-wave={max_wave}", f"--jsonl={out}", "--fresh-meta", "--no-juice"] + (["--unlock-all=1"] if unlock_all else [])
    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log = open(log_path, "a")
    seq = 0
    decided = 0
    while proc.poll() is None:
        state_path = os.path.join(POLICY_DIR, f"state_{seq}.json")
        if not os.path.exists(state_path):
            time.sleep(0.01)
            continue
        with open(state_path) as f:
            state = json.load(f)
        move, reason = backend(state)
        log.write(json.dumps({"seq": seq, "seed": state["seed"], "t": state["t"], "wave": state["wave"],
                              "ram": f"{state['ram_used']}/{state['ram_max']}", "bytes": state["bytes"],
                              "move": move, "reason": reason}) + "\n")
        log.flush()
        tmp = os.path.join(POLICY_DIR, f"move_{seq}.json.tmp")
        with open(tmp, "w") as f:
            json.dump({"move": move}, f)
        os.replace(tmp, os.path.join(POLICY_DIR, f"move_{seq}.json"))
        seq += 1
        decided += 1
        if decided % 25 == 0:
            print(f"  {decided} decisions, game t={state['t']} wave={state['wave']} ram={state['ram_used']}/{state['ram_max']} bytes={state['bytes']}")
    tail = proc.stdout.read()
    for line in tail.splitlines():
        if line.startswith("autoplay run") or "SCRIPT ERROR" in line or line.startswith("seed="):
            print(line[:200])
    log.close()
    print(f"{decided} decisions; run rows in {out}; decision log in {log_path}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("godot")
    ap.add_argument("--backend", choices=["heuristic", "claude"], default="heuristic")
    ap.add_argument("--model", default="claude-opus-5-5")
    ap.add_argument("--effort", default="low", choices=["low", "medium", "high", "xhigh", "max"])
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--seed", type=int, default=300)
    ap.add_argument("--max-wave", type=int, default=3)
    ap.add_argument("--decision-interval", type=float, default=1.0, help="game seconds between decisions")
    ap.add_argument("--unlock-all", action="store_true", help="play with every content unlock in the pool")
    a = ap.parse_args()
    backend = heuristic if a.backend == "heuristic" else ClaudeBackend(a.model, a.effort)
    os.makedirs("runs", exist_ok=True)
    out = serve(a.godot, backend, a.runs, a.seed, a.max_wave, a.decision_interval, os.path.join(POLICY_DIR, "decisions.jsonl"), a.unlock_all)
    subprocess.run([sys.executable, "tools/summarize_runs.py", out])


if __name__ == "__main__":
    main()
