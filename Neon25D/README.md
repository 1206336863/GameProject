# 霓虹夜市 · 原生 2.5D 可玩首版

Blender 4.5.2 LTS 建模 → GLB → Godot 4.7.2。使用立体模型、正交镜头、原生 3D 物理与动态灯光，玩法限制在水平面。

## 本机环境与启动

检查结果：Blender 安装于 `C:\Program Files\Blender Foundation\Blender 4.5`，显卡 NVIDIA RTX 4060；PATH、安装记录和常见目录中未发现 Godot / Unity / Unreal。已从 Godot 官方下载免安装 4.7.2 引擎，放在仓库根目录的 `tools/godot`（忽略提交）。不修改系统 PATH、注册表或其他项目。

- 双击本目录 `Start-Game.bat`：首次导入 GLB，然后启动游戏。
- 双击 `Open-Editor.bat`：打开可编辑 Godot 工程。
- Blender 源文件：`art_source/NeonMarket_Assets.blend`。
- 独立 Windows 运行包另行提供，内含已签名 Godot 运行时与游戏 PCK，无需安装 Blender / Godot 即可运行。

朋友首次克隆仓库后，可用 PowerShell 执行 `./Neon25D/scripts/setup_engine.ps1` 从官方网站下载同版本引擎。启动脚本也会在引擎缺失时调用此脚本。

## 操作

WASD / 方向键移动；鼠标瞄准、按住左键射击；空格单次冲刺；E 与中央货箱、商店和事件交互；Esc 暂停；F11 全屏。

清场后走到右侧霓虹出口中央进入下一间房。旧房间可以从左侧返回。暂停可重开或返回菜单。

## 首版内容

- 11 个原创 Blender 模型：三种摊位、玩家、四类敌人、Boss、货箱和灯笼。
- 立体摊位、中文几何招牌、灯笼、彩色点光源、实体货箱、地板与毒池变体。
- 12 个街区；前三间固定入门战斗、组合战斗、免费回血与商店，随后随机战斗 / 宝藏 / 商店 / 事件，最终 Boss。
- 14 项强化，包含多重弹道、穿透、雷电链、冻结、爆炸、吸血和环绕刃；冻结 + 爆炸、环绕刃 + 吸血、雷电击杀回充冲刺可联动。
- 追击者、枪兵连射、突进者、蓄力坦克，以及预警轰击 / 扇形弹幕 / 冲锋 Boss。原生角色及子弹被 3D 碰撞体阻挡。
- 商店拉面不限量、枪管独立限购；敌人回血掉落与保底；Boss 奖励自动领取。
- 音效、伤害数字、Boss 血条、冲刺冷却、死亡重开、胜利结算、永久印记与角色 / 武器解锁。

这是独立的 Windows 原生首版。原网页 3.0 保留在仓库根目录。浏览器存档不会自动迁入 Godot；原生存档在 Godot `user://progress.cfg`，测试模式不保存进度。手机触控、原版两项进阶强化、完整评级统计、骨骼动画及更丰富地形仍属于后续迁移与美术打磨内容；当前角色采用程序化朝向和行走起伏动画。

## 资产工作流

在本目录运行：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' --background --factory-startup --python art_source/build_assets.py
```

脚本以米为单位创建网格、材质与中文几何招牌，逐件导出 `assets/*.glb`，同时保存 Blender 资产库。脚本重建会覆盖这些生成文件；手工修改 .blend 后，应另存或手动导出相应模型，避免被下次重建覆盖。

碰撞体由 Godot 根据物件放置尺寸建立。摊位 2.8 × 2.4 × 1.7 米，货箱与角色胶囊有真实碰撞，子弹以连续射线检测掩体。

## 验证与打包

```powershell
$engine = '../tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path . --editor --import
& $engine --headless --path . --quit-after 600 -- --test
& $engine --headless --path . --export-pack 'Windows Desktop' '绝对输出路径/NeonMarket25D.pck'
```

成功标记为 `NEON25D_TESTS_OK`。测试覆盖模型和房间、基础解锁、单次冲刺、连续购物与库存、强化、Boss 奖励、死亡重开、真实掩体阻挡角色 / 子弹、掉落保存。源工程和独立 PCK 均已验证，并在本机 RTX 4060 上实际渲染截图。

独立包使用官方未修改的 Godot 可执行文件作为运行时加载 PCK，非定制导出模板生成的精简 EXE；因此体积较大。官方运行时采用 MIT 许可，包内附 Godot 许可证。游戏资产与源码归本项目维护。
