#!/usr/bin/env python3
"""Verify and summarize the exploratory fixed-kit 90-second scene samples."""
import hashlib
import json
from collections import Counter
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "render-evidence"
PERKS = {"balanced": "均衡", "adrenaline": "逆境反击", "leech": "命中回复", "enemy_swim": "敌墨潜游", "vault_runner": "翻墙加速", "last_ink": "残墨引爆", "dry_focus": "极限省墨", "turf_engine": "涂地充能"}
ITEMS = {"bomb": "墨水手雷", "intel_mist": "信息墨雾", "beacon": "跳跃信标", "recall": "回溯锚", "sonar": "脉冲声呐", "mine": "感应墨雷", "echo_decoy": "回声诱饵", "supply_box": "接力补给盒", "ink_wings": "墨翼背包"}


def main():
    data = json.loads((EVIDENCE / "swim25-perk-items.json").read_text())
    rounds = data["rounds"]
    if len(rounds) != 18 or {r["case"] for r in rounds} != set(range(18)):
        raise ValueError("Expected eighteen distinct rounds")
    for name, digest in data["source_sha256"].items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Production source changed after measurement: {name}")
    for r in rounds:
        if not r["results"] or abs(r["simulation_seconds"] - 90) > .05 or len(r["actors"]) != 10:
            raise ValueError(f"Incomplete natural round: {r['case']}")
        if any(a["weapon"] != "shooter" or a["item"] != r["item"] for a in r["actors"]):
            raise ValueError("Unexpected weapon/item reroll")
        for team in range(2):
            turf = sum(a["stats"]["turf"] for a in r["actors"] if a["team"] == team)
            if abs(turf - r["team_cumulative_turf_m2"][team]) > .01:
                raise ValueError("Individual/team paint ledger differs")
    bots = [dict(a, map=r["map"]) for r in rounds for a in r["actors"] if not a["local_player"]]
    if len(bots) != 162 or set(a["perk"] for a in bots) != set(PERKS) or Counter(a["item"] for a in bots) != Counter({k: 18 for k in ITEMS}):
        raise ValueError("Unexpected talent/item group distribution")
    repeat = json.loads((EVIDENCE / "swim25-perk-items-case-0.json").read_text())["rounds"][0]
    first = rounds[0]
    repeat_equal = repeat == first
    repeat_text = "case 0 独立重跑的全部战绩、时间、位移、能力记录和最终覆盖率相同。" if repeat_equal else "case 0 独立重跑出现差异，未认定模拟完全确定；保留两份原始数据。"
    lines = ["# 天赋／道具分组首轮对照 · 2026-10-03", "",
             "回廊展馆与阶梯花园各9场完整90秒，共18场／162个机器人单局样本，覆盖全部8天赋与9道具。",
             "主武器统一喷枪，固定配装、死亡不重摇；机器人天赋在编号／阵营间轮换，同局道具相同。保留实际射击、地形碰撞、导航、大招、逆风支援、自然伤害／死亡／复活与结果。",
             "本地玩家用正常移动／射击／潜墨／跳跃／E输入，固定敌墨潜游，排除于以下机器人均值。", "",
             "## 天赋", "", "| 天赋 | 样本 | 涂地 m² | 有效伤害 | 击倒 | 阵亡 | 存活占比 | 敌墨潜游秒 |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for key, label in PERKS.items():
        group = [a for a in bots if a["perk"] == key]
        lines.append(f"| {label} | {len(group)} | {mean(a['stats']['turf'] for a in group):.1f} | {mean(a['stats']['damage'] for a in group):.1f} | {mean(a['stats']['kills'] for a in group):.2f} | {mean(a['stats']['deaths'] for a in group):.2f} | {mean(a['alive_seconds']/90*100 for a in group):.1f}% | {mean(a['enemy_swim_seconds'] for a in group):.2f} |")
    lines += ["", "## 道具", "", "| 道具 | 样本 | 涂地 m² | 有效伤害 | 阵亡 | 存活占比 | CD启动次数 |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for key, label in ITEMS.items():
        group = [a for a in bots if a["item"] == key]
        lines.append(f"| {label} | {len(group)} | {mean(a['stats']['turf'] for a in group):.1f} | {mean(a['stats']['damage'] for a in group):.1f} | {mean(a['stats']['deaths'] for a in group):.2f} | {mean(a['alive_seconds']/90*100 for a in group):.1f}% | {sum(a['item_cd_starts'] for a in group)} |")
    swimmer = [a for a in bots if a["perk"] == "enemy_swim"]
    locals_ = [a for r in rounds for a in r["actors"] if a["local_player"]]
    supply_rounds = [r for r in rounds if r["item"] == "supply_box"]
    lines += ["", "## 观察与边界", "",
              f"敌墨潜游机器人实际潜游累计 {sum(a['enemy_swim_seconds'] for a in swimmer):.2f} 秒；本地玩家累计 {sum(a['enemy_swim_seconds'] for a in locals_):.2f} 秒。这些是自然接触样本，不能替代单独验证的6 HP/s和20 HP上限。",
              f"两场补给盒样本合计领取 {sum(r['supply_received'] for r in supply_rounds)} 份；回声诱饵共引发 {sum(r['decoy_fooled'] for r in rounds)} 次目标转移，墨翼全场施放 {sum(r['wing_casts'] for r in rounds)} 次。能力可用次数或触发次数偏少的组不能仅凭均值判断强弱。",
              "CD启动次数来自真实剩余CD由低到高的变化，包含回溯返回／锚销毁／过期后进入CD；它不是所有道具的部署次数。信标尚无机器人自动跳跃，因此本组未测完整团队转移收益。",
              "样本采用固定30Hz无渲染加速模拟，每局由真实物理帧推进到90秒，没有局中传送、强制扣血、直接涂色、跳过计时或终场。每局个人涂地之和与两队账本一致，生产脚本哈希已核验。", repeat_text,
              "每图仅一个种子，角色共享对局、路线与交战机会，天赋在阵营和道具间分布不完全相同；这是探索性分组，不能当因果比较、公平胜率或真人反制手感。高度记录包含跳跃／墨翼，不等价于稳定登上某个平台。未测原生帧率、GPU或温度，也未据此继续修改其他配装数值。",
              "", "原始数据：[18场样本](swim25-perk-items.json)、[独立重跑](swim25-perk-items-case-0.json)、[运行日志](swim25-perk-items.txt)。", "", "复现：", "", "```sh",
              "/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 30 --disable-render-loop --path . --script tools/measure_perk_items.gd",
              "/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 30 --disable-render-loop --path . --script tools/measure_perk_items.gd -- --case=0", "python3 tools/summarize_perk_items.py", "```", ""]
    path = EVIDENCE / "swim25-perk-items-summary.md"
    path.write_text("\n".join(lines))
    print(f"PASS: 18 natural rounds / 162 fixed-kit bots / 8 talents / 9 items / all source hashes and paint ledgers; repeat_equal={repeat_equal}; {path}")


if __name__ == "__main__":
    main()
