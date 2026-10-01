#!/usr/bin/env python3
"""Package the already exported arm64 app; no upload or repository mutation."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    parser.add_argument('--source-commit', help='Commit of the standalone release snapshot')
    parser.add_argument('--release-url', help='GitHub release page for this build')
    args = parser.parse_args()
    if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-[a-z0-9]+\.\d+)?', args.version):
        parser.error('version must look like v0.3.0-preview.2')
    if args.source_commit and not re.fullmatch(r'[0-9a-f]{40}', args.source_commit):
        parser.error('source-commit must be a full Git commit SHA')
    project = Path(__file__).resolve().parents[1]
    app = project / 'build/INKWAVE Demo.app'
    plist = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    executable = app / 'Contents/MacOS' / plist['CFBundleExecutable']
    pck = app / 'Contents/Resources/INKWAVE Demo.pck'
    architecture = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    if architecture != 'arm64':
        raise RuntimeError('Only arm64 packaging is supported')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    stem = f'INKWAVE-Godot-Demo-{args.version}-macOS-arm64'
    with tempfile.TemporaryDirectory(prefix='inkwave-package-', dir=project / 'build') as temp:
        stage = Path(temp) / stem
        stage.mkdir(exist_ok=True)
        subprocess.run(['ditto', str(app), str(stage / app.name)], check=True)
        shutil.copytree(project / 'licenses', stage / 'licenses', dirs_exist_ok=True)
        shutil.copy2(project / 'THIRD_PARTY_NOTICES.md', stage / 'THIRD_PARTY_NOTICES.md')
        shutil.copy2(project / 'RELEASE_NOTES.md', stage / 'RELEASE_NOTES.md')
        shutil.copy2(project / 'GAMEPLAY.md', stage / 'GAMEPLAY.md')
        shutil.copy2(project / 'BALANCE_REPORT.md', stage / 'BALANCE_REPORT.md')
        (stage / 'render-evidence').mkdir()
        for name in ['expand14-loadout-measurement.json', 'expand14-measure_expand14.txt', 'expand14-full-matches.json', 'expand14-ui-final.txt', 'expand14-responsive.txt', 'expand14-checks-final.txt', 'expand14-pck.txt', 'expand14-pck-ui.txt', 'expand14-app.txt']:
            shutil.copy2(project / 'render-evidence' / name, stage / 'render-evidence' / name)
        for name in ['results-loadouts-checks-final.txt', 'match-loadouts.json', 'match-loadouts-summary.md', 'match-loadouts.txt', 'turf-results.txt', 'turf-results-1280x720.png', 'turf-results-960x540.png', 'preview15-snapshot-checks.txt', 'preview15-pck.txt', 'preview15-pck-ui.txt', 'preview15-app.txt']:
            shutil.copy2(project / 'render-evidence' / name, stage / 'render-evidence' / name)
        (stage / 'README.md').write_text(f'''# INKWAVE {args.version} · arm64 预览版

解压后打开 INKWAVE Demo.app。仅 Apple Silicon / arm64。
应用为临时签名、未经 Apple 公证；若首次打开被 macOS 拦截，可在系统设置的隐私与安全性中确认允许打开。

打开先进入主菜单，再进入配装。默认单机 5v5，支持七张地图、十九套布局和模块组合、1v1、90/180 秒。七武器、七种 CD 道具与十二种天赋在同页的三条滚动带选择，无需切换；赛前各选一个；全部机器人武器／道具默认随机，可关闭复活重摇。
地图选择为主体，真实 3D 地图可拖动／滚轮查看；全身预览可旋转、缩放、点按跳跃，选择待机／跑动／试射，聚焦后 WASD 移动、空格跳跃。RANDOM 随机形象与队伍配色。武器卡片取消左右分栏，悬停显示五星与详细属性；道具、天赋也有悬浮详情。
命中伤害数字弹起、上浮淡出，颜色跟随攻击方本局队色，数值为护盾后实际扣血；同目标连击合并，溢出截断，限额 24 标签。
WASD 移动、鼠标瞄准、空格跳跃、Shift 己方墨面／墨墙潜墨爬墙、左键主武器、F/Q 大招。
右键 / E 使用所选道具：手雷 6 秒 CD（右键按住瞄准、松开投掷、70 墨水），补充剂 12 秒、护盾 16 秒、跳跃信标 18 秒（35 墨水、45 秒／两次、每人一个）。新增爆墨瓶、减速墨雾、医疗领域，CD 10／15／18 秒，消耗 45／45／35 墨水。道具技师减少 CD 20%；其余新增天赋为命中回复、稳枪专注和循环墨泵。没有地图拾取与库存，死亡／重摇保留 CD。
死亡立即显示地点选择与 4 秒倒计时，点队友／信标一次排队，到零发射，Esc 取消，J 再打开；基地保留鼠标 / WASD 瞄准、左键 / 空格 / Enter 出场。死亡 R 重摇装备，天赋整局不变。
存活 J 选目标，1 秒可受伤／可取消蓄势，公开落点预告，按实际楼层核验，信标要求己方墨地；落地不回血、不补墨，冷却 4 秒。目标失效回退，机器人可放信标、尚不自动跳跃。
Tab 战术地图，Esc 暂停，暂停／结算返回主菜单。结算地图放大、无外框与黑色留白，双方比例与分队战绩同时显示；编号／武器／击倒／阵亡／有效伤害／个人累计涂地分列对齐。自己的行高亮，最高击倒／涂地标金色。累计新占面积（含反复覆盖敌墨）与最终占地比例是不同指标。
所有角色都有一局固定的名字和编号，机器人按涂地充大招、重击／墨雨共用阵营伤害并有基本躲雨。
菜单移植项目网页 Logo、字体、图标和导航布局，七武器有浮动五星属性；原版音乐音效与结果舞蹈保留。新增珊瑚集市、回廊展馆、双层高架，回廊有 0/3/6 米三层平台与坡道；原两图可选三种安全布置；新增模块港湾（3×3 中央／侧路组合，种子选择，换图保持配装）和阶梯花园（0／3／6 米平台）。当前有限组合预先同步导出碰撞、墨面、导航与小地图。后续见 GAMEPLAY.md。
基础 120 HP（强健天赋 150），喷溅枪近端 30，四发击倒，远端衰减；满蓄狙 100、爆破直击 82，滚筒整轮甩墨共享伤害预算；直接命中有头部／躯干／腿部倍率，普通单次最高 115，死亡显示近期伤害。十二种天赋赛前选择，整局固定，复活／重摇不变；大招发动回满墨水，重击和 8 秒墨雨增加范围与反馈。Shift 墨墙攀爬加快并支持横向靠墙。
保留原眼睛、眉毛和状态表情；墨镜换成星星、闪电、波纹、菱形、花瓣、点阵、短线或月牙，随机颜色／大小／位置／单双侧，一局内预览和重生保持一致。保留原人物身体、服装、发型以及之前的肩袖、短裤裆部修正。原四武器、动作与潜墨保留。解析曲面采样细化、完整角色模型约 7.9 万三角（包含潜墨与四个源武器），人物预览开启 4×MSAA。新增武器模型由源喷枪／爆破枪派生。
修复角色血条，头顶、HUD、名单与小地图共用稳定角色编号；小地图沿用网页版底图与平滑墨色。修复快速射击／投弹点击、连续射击节奏及警告牌涂色闪烁，机器人接入原版跳跃边，补齐命中／击倒／潜墨／起跳反馈。死亡界面和消息显示击倒者编号、名字及发射时武器。
机器人按武器射程与交战距离接近目标，长管／蓄力狙不再统一限制在 8 米；遮挡与实际弹道保持。
默认 30 FPS / 75% 画面精度。本轮 83 项回归、两种窗口原生结算／返回按钮与两图八场完整 90 秒无渲染自动对局通过。182 组受控攻击、84 组墨量配置和 72 个固定配装机器人单局样本见 BALANCE_REPORT.md；天赋／道具、高层地图和真人手感继续待对照。自动模拟不提供 GPU 帧率或温度证据；旧原生地图回放为历史基线，未知桥梁漏染位置未定位。

修复范围与未完成项见 RELEASE_NOTES.md。
发布页面：{args.release_url or '本地构建'}
''')
        source_head = subprocess.check_output(['git', '-C', str(project.parent), 'rev-parse', 'HEAD'], text=True).strip()
        manifest = {
            'version': args.version, 'engine': 'Godot 4.8.dev6', 'architecture': architecture,
            'bundle_version': plist['CFBundleShortVersionString'],
            'bundle_build': plist['CFBundleVersion'],
            'source_head': args.source_commit or source_head,
            'source_kind': 'release-snapshot' if args.source_commit else 'workspace-base',
            'executable_sha256': sha(executable), 'pck_sha256': sha(pck),
            'signature': 'ad-hoc; codesign --verify --deep --strict passed', 'notarized': False,
            'release_url': args.release_url,
        }
        (stage / 'BUILD.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        archive = project / 'build' / f'{stem}.zip'
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(stage), str(archive)], check=True)
        subprocess.run(['unzip', '-tq', str(archive)], check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    checksum = project / 'build' / f'INKWAVE-Godot-Demo-{args.version}-SHA256SUMS.txt'
    checksum.write_text(f'{sha(archive)}  {archive.name}\n')
    print(json.dumps({'archive': str(archive), 'sha256': sha(archive), 'bytes': archive.stat().st_size}, ensure_ascii=False))


if __name__ == '__main__':
    main()
