#!/usr/bin/env python3
"""Summarize the fixed-kit full-round sample without treating it as a balance verdict."""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[2]
WEAPONS = {
    "shooter": "喷溅枪", "roller": "滚筒刷", "charger": "蓄力狙",
    "blaster": "爆破枪", "dualie": "双持喷枪", "heavy": "长管喷枪", "rapid": "轻爆枪",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "render-evidence/match-loadouts.json")
    parser.add_argument("--output", type=Path, default=ROOT / "render-evidence/match-loadouts-summary.md")
    args = parser.parse_args()
    data = json.loads(args.input.read_text())
    rounds = data["rounds"]
    if len(rounds) != 8 or len({r["case"] for r in rounds}) != 8:
        raise ValueError("Expected eight distinct completed cases")
    for name, expected in data["source_sha256"].items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != expected:
            raise ValueError(f"Measured gameplay source has changed: {name}")
    for r in rounds:
        if not r["results"] or abs(r["simulation_seconds"] - 90) > 0.05 or len(r["actors"]) != 10:
            raise ValueError(f"Incomplete round: {r['case']}")
        for team in range(2):
            total = sum(a["stats"]["turf"] for a in r["actors"] if a["team"] == team)
            if abs(total - r["team_cumulative_turf_m2"][team]) > 0.01:
                raise ValueError(f"Lost paint attribution: case {r['case']}, team {team}")
    bots = [dict(a, map=r["map"]) for r in rounds for a in r["actors"] if not a["local_player"]]
    if len(bots) != 72 or any(a["perk"] != "balanced" or a["item"] != "refill" for a in bots):
        raise ValueError("Unexpected kit conditions")
    lines = [
        "# 七武器多局自动对照 · 2026-10-01", "",
        "两张原地图各四种种子，共八场完整 90 秒、72 个机器人单局样本。均衡天赋、补充剂固定，死亡不重摇武器；",
        "保留武器对应大招、实际弹道、碰撞、导航、自然死亡和复活。玩家通过正常输入移动／射击／潜墨／跳跃，计时自然结束。", "",
        "下表排除本地喷枪玩家。每格为每机器人每局均值，涂地指累计新占面积（含反复覆盖敌墨），存活包含出生保护期。", "",
        "| 武器 | 样本 | 涂地 m² | 有效伤害 | 击倒 | 阵亡 | 存活时间占比 |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for weapon, label in WEAPONS.items():
        rows = [a for a in bots if a["weapon"] == weapon]
        lines.append(f"| {label} | {len(rows)} | {mean(a['stats']['turf'] for a in rows):.1f} | "
                     f"{mean(a['stats']['damage'] for a in rows):.1f} | {mean(a['stats']['kills'] for a in rows):.2f} | "
                     f"{mean(a['stats']['deaths'] for a in rows):.2f} | {mean(a['alive_seconds']/90*100 for a in rows):.1f}% |")
    lines.extend(["", "## 样本分布", "",
                  "各武器在阵营、地图、路线与交战机会上的分布不同；同局角色也非独立样本。以下保留分组数量，避免只看总体均值。", "",
                  "| 武器 | 己方 / 对方 | Tidewater / Kelpline |", "| --- | ---: | ---: |"])
    for weapon, label in WEAPONS.items():
        rows = [a for a in bots if a["weapon"] == weapon]
        lines.append(f"| {label} | {sum(a['team']==0 for a in rows)} / {sum(a['team']==1 for a in rows)} | "
                     f"{sum(a['map']=='tidewater' for a in rows)} / {sum(a['map']=='kelpline' for a in rows)} |")
    lines.extend(["", "## 解释与边界", "",
                  "本批机器人样本中，蓄力狙和长管喷枪的伤害／涂地均值偏高。机器人可直接瞄准可见目标，",
                  "不能代表真人蓄力命中率、掩体使用或公平胜率；本批保留生产伤害数值。还需天赋／道具分组、高层地图与人工手感对照。", "",
                  "实际交战上限已从统一 8 米改为武器射程；1v1 与 5v5 的 14 米长管、22 米满蓄狙实际命中及墙体遮挡另有回归。", "",
                  "这是固定 30 Hz 的无渲染加速模拟，完整 90 秒由场景物理帧推进，不是原生帧率／GPU／温度测量。",
                  "八局的个人涂地之和均与团队账本一致。case 0 单独重复的战绩、存活、移动记录与最终覆盖率完全相同；不保证跨版本／设备的物理确定性。", "",
                  "原始数据：[match-loadouts.json](match-loadouts.json)，运行日志：[match-loadouts.txt](match-loadouts.txt)。", "",
                  "复现（项目目录内）：", "", "```sh",
                  "/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 30 --disable-render-loop --path . --script res://tools/measure/measure_match_loadouts.gd",
                  "python3 tools/measure/summarize_match_loadouts.py", "```", ""])
    args.output.write_text("\n".join(lines))
    print(f"PASS: eight natural 90-second rounds, 72 fixed-kit bot samples, source hashes and team turf totals verified; {args.output}")


if __name__ == "__main__":
    main()
