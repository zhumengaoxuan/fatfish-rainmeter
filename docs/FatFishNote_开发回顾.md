# FatFishNote 开发回顾日志（2026-10-24 会话）

> 用途：给「下一个我」看的交接笔记。读完这份，不用重新摸一遍环境和坑。
> 项目位置：`C:\Users\朱门高悬云帆\Documents\Rainmeter\Skins\FatFishNote`
> 打包产物：`C:\Users\朱门高悬云帆\.dsh\im\FatFishNote_1.3.rmskin`
> 打包脚本：`C:\Users\朱门高悬云帆\.dsh\im\pack_rmskin.py`

---

## 一、环境与工具链

| 项 | 值 |
|---|---|
| Rainmeter | 5.0.0.5293 64-bit，`C:\Program Files\Rainmeter\Rainmeter.exe` |
| 皮肤目录 | `C:\Users\朱门高悬云帆\Documents\Rainmeter\Skins\` |
| 日志 | `C:\Users\朱门高悬云帆\AppData\Roaming\Rainmeter\Rainmeter.log` |
| Python | `C:\Users\朱门高悬云帆\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| 临时脚本 | 统一放 `C:\Users\朱门高悬云帆\.dsh\im\`，前缀 `_` |

**文件编码是硬约束，写错会静默失败或整文件清零：**

| 文件 | 编码 | 换行 |
|---|---|---|
| `FatFishNote.ini`、`settings.ini` | UTF-16 LE | CRLF |
| `Note.lua`、`Weather.lua`、`Settings.lua` | GBK | CRLF |
| `notes.txt`、`autonote.txt`、`city.txt`、`calday.inc` | GBK | CRLF |
| `RMSKIN.ini`（打包时生成） | GBK | CRLF |

写文件务必：先用 `open(..., 'wb')` / `open(p,'w',encoding='gbk')` 一次性写完整字符串，**不要**边拼边写；注释里别用 `⇒`「」以外的非 GBK 字符。

---

## 二、文件地图

```
Skins\FatFishNote\
├─ FatFishNote.ini        (UTF-16, ~135KB) 主皮肤：面板/标题/时钟/日历/卡片/容器/右键菜单
├─ settings\
│   ├─ settings.ini       (UTF-16, 421×443) 配置页
│   └─ Settings.lua       (GBK) 配置页逻辑：模式、天气城市、保存
└─ @Resources\
    ├─ Note.lua           (GBK, ~67KB) 全部布局与交互逻辑
    ├─ Weather.lua        (GBK) Open-Meteo 天气 + 城市地理编码
    ├─ notes.txt          (GBK) 便签数据 v3
    ├─ autonote.txt       (GBK) 自动便签配置
    ├─ city.txt           (GBK) `城市|lat|lon`
    └─ calday.inc         (GBK) 31 个 CNString 农历日名
```

**辅助资料（在 .dsh\im\）**：`pack_rmskin.py`、`Rainmeter坐标规则.md`、`Shape_5.0_手册整理.md`、各种截图 `*.png`。

---

## 三、数据格式

### notes.txt（v3）

```
#FatFishNote v3
#grid cols=2 rows=1 scale=1.00
#theme 1
#page 0
date \t name \t text \t source \t theme
```

- `source`：`user` / `ai` / `auto`
- 第 5 列 `theme`：1–4，缺省 1，按行生效（每张便签独立主题）
- 解析要容错：老文件没有第 5 列时补 1

### autonote.txt

```
#modes cycle,date          ← 多选模式列表（空则一个都不生成）
#mode cycle                ← 兼容旧版，取第一个
#cycle 2
#base 2026-01-01
1\t订货\t确认下单数量
2\t到货\t核对到货清单
#interval 7
#tname 交周报
#ttext 整理本周进度并发给组长
#dday 24
#dname 交周报
#dtext 整理本周进度并发给组长
```

### city.txt

```
大同|40.0902|113.3001
```

---

## 四、关键机制（改代码前必读）

1. **`resolvePaths()` / `resolveCity()`**
   Lua 加载时 `SKIN` 可能为 nil，此时路径会算成相对路径 → 读文件静默失败。
   约定：模块顶部 `pcall(resolvePaths)`，并在 `boot()`、`readCity()`、`saveCity()`、`update()` 等入口**再调一次**。
   所有 `readFile(p)` 在 `p == nil` 时**必须直接返回 nil，不能回退到 notes.txt**（这条踩过大坑，见错误 #2）。

2. **布局入口 `layout()`**
   计算 `baseDate = today - page`、列/行、卡片尺寸，写 `SH`/`SW` 变量，然后 `applyTheme()`、设置各固定米特坐标、日历、卡片。

3. **每张便签主题**
   `isAI` 判断必须是 `notes[i].src == 'ai'`（曾经写成 `~= 'user'`，导致 auto 便签全丢颜色）。

4. **色板（swatches）**
   共用 4 个 `Sw_1..4`（Shape 圆 `Ellipse 8,8,7,7`），`hoverCard(m)` 显示、`leaveCard()` 立即隐藏（先隐藏→再移动→最后显示，顺序不能反）。

5. **跑马灯（右上两行）**
   - 容器 `[RightClip]`：`Meter=Shape`，`X=bandX-LP`，`Shape=Rectangle 0,0,(LP+bandW+RP),68 | StrokeWidth 0 | Fill LinearGradient 1`
   - 渐隐必须在**水平**方向 → 角度 **180**（0 右→左、90 下→上、180 左→右、270 上→下）
   - 子米特 **必须写 `Container=RightClip`**，坐标是**相对容器**的：`Y=0` / `Y=16`，`X = LP + bandW - RP - off`
   - 文本用「正文 + 间隔」重复三份，`off` 在一份宽度内归零 → 无缝
   - `[MarqueeTick]`：`UpdateDivider=4`（约 15fps），`marqueeAdvance()` 每次 +2px

6. **自动便签生成顺序**
   `saveAll()` → 先 `reloadAuto()` 再 `clearAllSkips()`；生成后按「日期升序 + 同日期 auto 在前」稳定排序。

7. **主题 `#theme` 与每张便签的 `theme` 是两套东西**：前者管面板/日历/天气/配置页，后者管卡片。

---

## 五、错误档案（按发生顺序，附根因）

### 1. `Note.lua` 被写成 0 字节
写 GBK 时先 `open(...,'w')` 再逐步格式化，中途异常 → 文件清空，报 `marqueeAdvance is a nil value`。
**修**：整串拼好再一次性写；改完立刻从 .rmskin 里 `zipfile.read` 恢复验证。

### 2. 便签重复生成（每张 auto 便签多出一条 ai 副本）
`readFile(p)` 在 `p` 为 nil 时回退去读 `notes.txt`，`aiTick()` 于是把便签本体当 AI 便签又导入一遍，每条变成 `保险\t…\tauto\t1` + 同名 `ai` 行。
**修**：`readFile(nil)` 直接返回 nil，禁止回退。

### 3. `attempt to call global 'layout' (a nil value)`
`layout` 是后声明的 local，前面的函数看不到。
**修**：统一调用 `relayoutWeather()`（后声明、已注册为全局）。

### 4. `SWATCH_COLORS is a nil value` / `dotBox` 用了作用域外的 `rad`
**修**：常量前置；删掉依赖越界变量的函数。

### 5. `!HideMeter: [SwNN_N] not found`（4202 行日志）
旧版给每张卡片建了色板米特，后改为共用 4 个，但 `hideCard` 还在循环隐藏不存在的米特。
**修**：删掉循环，只隐藏 `Sw_1..4`。

### 6. `.rmskin` 安装报 `Invalid package … The Skin Packager tool must be used`
自己 zip 出来的包没有 16 字节 trailer。
**修**：`struct.pack('<Q', len(zip)) + b'\x00RMSKIN\x00'` 追加在末尾，用 `pack_rmskin.py` 统一打包。

### 7. `!Refresh: Skin "FatFishNote\FatFishNote.ini" is not active`
**修**：bang 里引用配置只能写 `FatFishNote`（配置名），不能带 .ini 路径。

### 8. `[LunarParent]: Invalid "GMDFeasts"…`（每次刷新 13 条）
用最小皮肤（只含 LunarParent + 一个 String）复现，13 个名字在 DLL 字符串表里连续存在 → **插件内部自校验噪音**，皮肤侧无法消除，忽略即可。

### 9. 配置页排版错乱（字段叠在一起）
新写的多选逻辑插在文件中段，调用的 `vis` / `layoutBottom` / `showRows` 是**后面才声明的 local** → 运行时 nil，`ipairs(nil)` 报错，布局只执行一半。
**修**：`MODE_KEYS / modeOn / panelMode` 提到文件顶部，整套函数移到**文件末尾**（所有辅助函数之后）。

### 10. `setCycle` / `preset` / `saveCity` 全变 nil
上一轮「整理代码」时按区间替换，把夹在中间的三个仍在被 ini 调用的函数一起删了。
**修**：补回；并建立习惯——**改完用脚本比对「ini 里 `!CommandMeasure SettingsLua "xxx("` 引用的函数」与「Lua 里 `^function` 定义」的差集**。

### 11. 保存配置完全没反应
`Settings.lua` 里有 **3 份 `saveAll` / 3 份 `setMode`** 旧副本，后定义的覆盖了新代码。
**修**：截掉重复段，只留一份；`saveAll` 开头 `pcall(resolvePaths)`（否则路径算成 `..\@Resources\autonote.txt` 相对路径，写盘静默失败）。

### 12. 城市按钮「坏了」
`Meter=TextEdit` 的打字内容**不会**写进变量，只有 `OnSubmitAction` / `OnDismissAction` 里的 `[$Input]` 才有值。所以 `saveCity()` 一直读到开机时的旧城市。
**修**：给 21 个 TextEdit 全部补
`OnSubmitAction=[!SetVariable xxx "[$Input]"]` + `OnDismissAction=…`；点按钮时输入框先失焦，顺序天然正确。
另：`saveCity` 查预设城市直接写经纬度（中文地理编码经常返回空）。

### 13. 自动便签不再置顶
多模式改成「并集」时把插入逻辑写成 `notes[count]=…` 追加，跑到了用户便签后面。
**修**：生成后按日期 + 同日期 auto 优先做稳定排序。

### 14. 跑马灯「逐字跳」且两行只有一行显示
三个叠加原因：
- 容器没写 `Container=` → 完全不裁剪（把 Shape 放前面不会自动生效）
- 子米特坐标是**相对容器**的，我按绝对坐标算 → 第二行落到容器外被裁掉
- `LinearGradient` 角度当成水平用了 `90`（其实是**下到上**）→ 文字上下被削淡

**修**：
- 子米特显式 `Container=RightClip`
- 只改容器 `X/W`，子节点用相对坐标 `Y=0/16`、`X=LP+bandW-RP-off`
- 水平渐变用 `180`
- 文字宽度用隐藏 `[RowMeasure]` 米特实测（`GetW()`），别用字符估算

### 15. 天气一直 `--°`
刷新后只靠 `FetchTimer`（Wait 20000）排队，实际没触发成功。
**修**：`boot()` 里直接 `!EnableMeasure MeasureWeather` + `!CommandMeasure MeasureWeather Update`。

---

## 六、用户纠正清单（这是最重要的部分）

按时间顺序，都是我被指出来的：

1. **不要先打包再说**——用户要看到效果/确认后才打包。
2. **色板米特写成了 `Meter=String`**，而且 `W/H` 对 Shape 没有意义 → 改为 Shape 圆。
3. **没有米特的测试皮肤不会被刷新**，`!Refresh` 直接报 not active → 之前「无报错」的结论作废。
4. **悬浮显示/隐藏的顺序**：必须先隐藏旧色板 → 再移动 → 最后显示，否则会看到残影。
5. **移开后不要延迟**，立即隐藏。
6. **模式按钮不要强制至少选一个**。
7. **`清空` 按钮的层级**：它属于「当前模式」，应该放在 `天 / 名字 / 正文` 标题行右侧，而不是和模式按钮平级。
8. **日期单发模式不需要「起始日期」**，去掉并重排。
9. **标题统一为 `FatFish便签` / `FatFish便签 设置`**（FatFish 两个大写 F）。
10. **右上两行的间距/右缘要与其它行对称**：子节点 `Y=18 → 16`；`X` 要比容器右缘再内收 `RP`。
11. **农历行要固定「今天」**，不能跟着翻页/选中日期跑。
12. **渐变角度**：`90` 是垂直，别拿它做水平渐隐（用户直接甩了手册 PDF 打脸）。
13. 反复强调：**报告必须是你亲眼验证过的**（读文件、截图、日志），不能凭记忆说「已修改」。

---

## 七、工作方法（下次直接照做）

### 验证三件套

1. **看文件**：改完立刻 `read` 回读关键片段，确认落盘。
2. **看日志**：`Get-Content …Rainmeter.log | Select-String 'ERRO|attempt' | -Last 5`。
3. **看像素**：截图。**窗口位置会漂！每次先枚举窗口取 rect，再按 rect 截图**，不要用记忆中的坐标。

```powershell
# 取窗口位置
Add-Type @" ...EnumWindows/GetWindowRect..."@
$r=...; Write-Output "$($r.Left),$($r.Top) $($r.Right-$r.Left)x$($r.Bottom-$r.Top)"
```

### 运行时探针

```lua
-- 临时用，别留在正式代码里
SKIN:Bang('!Log','X='..tostring(SKIN:GetMeter('Foo'):GetOption('X'))..' y='..tostring(SKIN:GetMeter('Foo'):GetY()),'Notice')
```

- `GetOption('Y')` 是**设定值**；`GetY()` 是**实际坐标**（容器内是相对值 + 容器偏移）
- 判断「某个函数是否真的存在」可以用 `tostring(fn ~= nil)` 打印
- `!CommandMeasure` 里的片段看不到文件里的 local，所以探针只能用全局

### 改代码的纪律

- 替换函数用**函数名锚点**（`function foo(` 到下一个 `^function`），不要用行号区间。
- 替换后跑一次「引用 vs 定义」差集检查（见错误 #10）。
- Lua 的 local 是**文件作用域**，重复定义后者生效 → 改完 `grep '^function xxx'` 数一下份数。
- 每次改完 `!Refresh` 对应配置；`!ActivateConfig` 对已激活的配置是**空操作**，别指望它重载。

### 打包

```python
sys.path.insert(0, r'C:\Users\朱门高悬云帆\.dsh\im')
import pack_rmskin as P
P.build(skin_dir, out_rmskin, 'FatFishNote', '肥鱼', '1.3',
        load_ini='FatFishNote\\FatFishNote.ini',
        min_rainmeter='5.0', min_windows='10.0',
        plugins={'64bit': r'...\Plugins\LunarCalendar.dll',
                 '32bit': r'...\_plugins\32bit\LunarCalendar.dll'})
```

必须保留 `MinimumRainmeter=5.0`（`Meter=TextEdit` 需要）。插件走 `Plugins/64bit` + `Plugins/32bit`。

---

## 八、当前状态（截至本会话结束）

**已完成**

- 每张便签独立配色（notes.txt 第 5 列），色板随卡片悬浮显示
- 右上：天气 + 农历两行，水平渐隐、右缘与日期行对齐、像素级无缝滚动
- 配置页：模式多选（单击开关 / 双击切面板）、每模式「清空」、日期单发无起始日期
- 城市切换（预设 + 自定义）、天气开机即抓
- 标题 `FatFish便签` / `FatFish便签 设置`
- 自动便签置顶、重复生成修复、零模式允许
- 打包 533 KB，含 LunarCalendar.dll 双架构

**已知遗留**

- `LunarCalendar.dll` 每次刷新吐 13 条 `Invalid "GMxxx"`，插件内部噪音，无法皮肤侧消除
- 便签皮肤与配置页缩放不联动（配置页固定 421 宽）
- AI 便签写入功能仍依赖外部往 `ai_drop.txt` 写入（DSH 侧）
- 用户手动改了 `nbdock++plus` 的参数（`num/a/b/size/s/c/over/rot`），**不要读、不要改、不要恢复**

**待观察**

- 跑马灯速度（31px/s）与 CPU 占用，用户尚未最终确认
- `previewLong()` 是为了看效果加的调试函数，确认后可以删

---

## 九、新会话启动清单

1. 读本文 + `Shape_5.0_手册整理.md`
2. `Get-Content Rainmeter.log -Tail 20` 看当前有无报错
3. 枚举窗口 rect，截一张当前皮肤图，确认视觉基线
4. 确认 `notes.txt` / `autonote.txt` 当前内容（用户可能已手动改过）
5. 改任何 Lua 前先备份到 `.dsh\im\_backup\`
6. 改完：回读文件 → 刷新 → 看日志 → 截图 → 再回报

---

## 十、版本控制（2026-10-24 建）

**已建本地 Git 仓库**：`Documents\Rainmeter\Skins\FatFishNote\.git`，跟踪 11 个文件，`.gitignore` 排除 `*.bak/*.tmp/*.log/*.rmskin`。

**重要限制**：DSH 沙箱里 **git.exe 无法创建文件**（`index.lock: Permission denied`），`git add/commit` 会失败，但 `git log / ls-tree / status` 这类只读命令正常。
所以提交动作统一走纯 Python 的 dulwich：

```powershell
$py = "...\python.exe"
& $py -X utf8 C:\Users\朱门高悬云帆\.dsh\im\ffn_git.py commit "说明"
& $py -X utf8 C:\Users\朱门高悬云帆\.dsh\im\ffn_git.py log 10
& $py -X utf8 C:\Users\朱门高悬云帆\.dsh\im\ffn_git.py status
```

**在你自己终端（非 DSH）里**，`git` 可直接用（MinGit 已加进用户 PATH：`.dsh\im\tools\git\cmd`），提交、diff、回滚都正常。

**血泪教训**：dulwich 的 `porcelain.rm` 会连工作区文件一起删。修索引只能 `del index[path]` + `index.write()`，绝不能用 rm。我因此删掉过 `.git/HEAD`，靠手写 `ref: refs/heads/master` 才救回来。

**回滚**：

```powershell
git -C <皮肤目录> checkout -- .          # 丢弃未提交改动
git -C <皮肤目录> reset --hard <commit>  # 回到某个提交
```
