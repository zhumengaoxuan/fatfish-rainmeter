# FatFishNote 经验总纲

> 给下一个接手的我。这份文件是**长期维护**的：每次做完一轮实质改动，就在文末「更新日志」追加一条，并同步改掉过时的段落。
> 最后更新：2026-10-26 上午

---

## 0. 三十秒速览

| 项 | 值 |
|---|---|
| 皮肤目录 | `C:\Users\朱门高悬云帆\Documents\Rainmeter\Skins\FatFishNote` |
| 主 ini | `FatFishNote.ini`（UTF-16LE，约 166 KB / 314 个节点） |
| 主脚本 | `@Resources\Note.lua`（GBK，约 91 K 字符） |
| Rainmeter | 5.0.0.5293 64-bit，`MinimumRainmeter=5.0`（`Meter=TextEdit` 需要） |
| 数据 | `notes.txt` / `favorites.txt` / `autonote.txt` / `city.txt`（全部 GBK 纯文本） |
| 版本控制 | dulwich 脚本 `~/.dsh/im/ffn_git.py`（DSH 里 `git.exe` 不能写） |
| 打包 | `~/.dsh/im/pack_rmskin.py`（16 字节 RMSKIN trailer） |
| 硬上限 | 便签 30 张（MAXN）、列 6（MAX_COLS）、历史页 4（PAGE_MAX）、收藏 50（FAV_MAX）、每页 6 条（FAV_PER） |

---

## 0.1 当前状态（每轮更新）

> 这一节放**会变的东西**。静态知识在 §1 之后，别往这里堆。

**功能清单**

| 功能 | 状态 |
|---|---|
| 时间轴分列（按日期）+ 翻页 | ✅ |
| 卡片拖拽换位、换日期、拖入删除 | ✅ |
| 常驻区：拖入固定 / 拖回时间轴 / 按位插入 | ✅ |
| 常驻区滚动 + 进度条（常显、点上翻下翻、溢出箭头） | ✅ |
| 收藏栏：面板、滚动、拖回、右键复制 | ✅ |
| 自动便签（每月/每周/每日规则） | ✅ |
| 节气、天气、日历、时钟 | ✅ |
| 常驻区便签的选中框 / 双击编辑 | ✅ |
| 收藏星标涟漪反馈 | ✅ |
| 卡片插图（右下探出 108px / 空白便签居中大图） | ✅ |
| 贴图面板（右键单击卡片：4 档配色 + 12 缩略图） | ✅ |
| 贴图自动发现（img 目录 + 扫描生成 list.txt） | ✅ |
| 卡片图片（背景/缩略图） | ❌ 未做（插图已另做） |
| 卡片预设（presets.txt） | ❌ 未做 |
| 热键快记（HotKey + TextEdit） | ✅ |
| 番剧便签（抓 yuc.wiki，每日一次，可关） | ✅ |

**当前数据**

- 网格：`cols=2`、`rows=4`、`scale=1.00`
- 固定便签：4 张（节气口径 / 热键快记 / 换堆谈法 / 番剧便签）
- 常驻区溢出现象：固定 4 张 > 可视 4 行时才会出进度条

**回档点**

- 最新提交：`6579d3a8`（时间列悬浮修复）
- 回档命令：`python ~/.dsh/im/ffn_git.py restore <提交号>`

**欠账**

- 交接文档（本节即替代方案）
- 便签里挂着的待办事项见 `notes.txt`

---

## 0.5 术语表（统一口径）

> 2026-10-27 定。Rainmeter 原生概念一律用英文（查手册零成本）；自有概念用固定中文。

**原生术语**

| 统一写法 | 别写 | 含义 |
|---|---|---|
| meter | 米特、计量器 | 屏幕上的绘制单元 |
| measure | 测量 | 取数据 / 计算的单元 |
| section / 节点 | 节、段 | ini 里的一个 `[Name]` |
| skin / 皮肤 | 插件 | 一个皮肤（plugin 另有其物） |
| container | 容器 | `Container=` 指定的 meter |
| mask | 蒙版 | 用于裁剪的 Shape |
| child meter | 子米特 | container 内的 meter |
| group | 组 | `Group=` |
| bang | 指令 | `!SetOption` 这类 |
| variable | 变量 | |
| built-in variable | 内置变量 | `#CRLF#`、`#CURRENTPATH#` |
| plugin | 插件 | C++ 插件 |
| script measure | 脚本测量 | `Measure=Script` |
| action | 动作 | `LeftMouseUpAction` 等 |
| UpdateDivider | 刷新倍率 | 不写「更新率」 |
| skin folder | 皮肤目录 | `Skins\` 下的一级目录 |
| .rmskin | 皮肤包 | 打包产物（包 ≠ 皮肤） |

**自有概念**

| 写法 | 含义 |
|---|---|
| 常驻区 | 左侧固定便签区（内部名 fixed zone） |
| 时间列 | 按日期分的列 |
| 卡片 | 一张便签对应的 meter 组合 |
| 落点预览 | 拖动时的 `DropHint` |
| 幽灵卡 | 拖动时跟随指针的 `GhostCard` |
| 磁吸 | 缩放吸附到档位 |

**命名约定**

- 跨函数共享的模块状态：小驼峰（`rows`、`cols`、`scale`、`dragIdx`、`pitch`、`cardH`）
- 常量：全大写（`B_MARGIN`、`B_CARD_W`）
- 状态表：全大写（`FIXUI`、`FAVUI`、`AUTO`）
- 写进 skin 的变量：全大写（`SW`、`SH`、`ROWS`、`COLS`）
- 控件命名：类型 + 序号（`Card0`、`Text0`、`CardClip0`、`FixedBar`）
- 「刷新」专指 `!Refresh`；重绘写「重画」（`!Redraw`）

## 1. 文件与职责

```
FatFishNote\
  FatFishNote.ini          主皮肤：所有米特、鼠标动作、主题、布局入口
  README.md                介绍页（随包发布）
  @Resources\
    Note.lua               全部逻辑：布局、数据、拖拽、收藏、跑马灯、自动便签
    Weather.lua            天气抓取与城市
    calday.inc             日历数据
    notes.txt              便签数据
    favorites.txt          收藏库
    favorites_deleted.txt  删除回收记录
    autonote.txt           自动便签规则
    city.txt               天气城市
  settings\
    settings.ini           配置页（自动便签、城市、模式）
    Settings.lua           配置页逻辑
```

`FatFishNote.ini` 里节点顺序 = 绘制顺序 = 鼠标命中顺序（后者见 §4）。

---

## 2. 编码硬约束（写错会静默失败）

| 扩展名 | 编码 |
|---|---|
| `*.ini` | UTF-16LE（带 BOM） |
| `*.lua` `*.txt` `*.inc` | GBK |

Python 读写模板：

```python
open(p, 'r', encoding='utf-16')   # ini
open(p, 'r', encoding='gbk', errors='ignore')  # lua / txt
```

写完必须回读验证：ini 至少确认节点数没掉，lua 至少跑一次语法检查（见 §11）。

---

## 3. 数据格式

### notes.txt

```
#FatFishNote v3
#grid cols=2 rows=3 scale=1.11
#theme 1
#page 0
#autoskip 2026-10-27
2026-10-26	标题	正文	user	1
```

- 行格式：`日期 \t 名字 \t 正文 \t 来源(auto/user/ai) \t 主题(1-4)`
- `#autoskip 日期`：表示该日期不要再自动生成便签（用户删过自动便签后留下的标记）
- `#page`：当前页码；`#grid` 里的 cols/rows/scale 会被布局覆盖，但解析时会读

### favorites.txt

```
#FatFishNote favorites v1
标题	正文	1	2026-10-26
```

字段：`名字 \t 正文 \t 主题 \t 收藏日期`

### autonote.txt

```
#modes monthly,interval
#mode monthly
#cycle 2
#base 2026-10-28
#interval 7
#tname 写观感
#ttext 正文
#dday 1
#dname 交周报
#dtext 正文
1	订货	确认下单数量
2	到货	核对到货清单
```

- **`#modes` 用逗号分隔**（`monthly,interval`）。用分号写会只认第一个 —— 踩过。
- `interval` 模式：`((dateDiff(base, d) % interval) + interval) % interval == 0`
- `monthly` 模式：按「当月第几天」在规则表里轮流取（`((day-1) % cycle) + 1`）
- `date` 模式：每月第 `dday` 天，用 `dname/dtext`
- 其余模式：按日期偏移在规则表里轮流取

---

## 4. 已实测的机制（别重新试）

### 4.1 绘制与命中

- **节点顺序决定绘制顺序**，后面的盖前面的。
- 鼠标命中看**实心像素**：`SolidColor=0,0,0,1` 的 String 能点，`Fill Color ...,0` 的 Shape **也能点**（alpha 0 不等于不可点）。
- 容器（`Container=`）会裁剪命中区：子米特超出容器的部分点不到。
- **容器同时约束窗口边界**：子米特 `H=2000` 被 200×100 的容器裁住，窗口不会变大（Test10 实测）。
- **被覆盖不会触发 leave**：遮罩盖住卡片，卡片的 hover 状态会滞留，tooltip 也会跟着滞留。所以不能靠「盖一层」来关掉下层，只能显式清状态。

### 4.2 bang 顺序

- bang 按书写顺序执行。
- **改几何后要立刻显示，必须 `!UpdateMeter` 再 `!ShowMeter`**：`!SetOption` 只改选项，几何要等 update 才重算；`!Redraw` 不重算几何。缺这一步会闪一帧旧位置。
- 批量收尾优先 `!UpdateMeter *` + 一次 `!Redraw`，别逐个 update。
- **隐藏时先 hide，几何可不动**；显示时先改几何、再 update、再 show。

### 4.3 颜色

- **`DynamicVariables=1` 会让米特每次更新重新解析它的选项**，所以 `FontColor=205,195,255,[Measure:]` 是能刷新的 —— 实测 `sv1/sv2/sv3` 亮度 443→496→560。
- 但**颜色分量必须是整数 0–255**。Calc 返回小数（如 `146.2879`）时该分量非法，颜色整条不生效，看起来就像「节变量不刷新」。**之前的真凶是小数，不是 DynamicVariables。**
- 修法二选一：`Formula=(Round(...))` 保持整数；或由 Lua 每 tick `setOpt` 设颜色（本项目现在用后者，因为面板打开时要暂停呼吸 —— 用节变量会被下一次 update 顶回去）。
- 如果度量内部引用变量，度量自身也要 `DynamicVariables=1`。

### 4.3.1 面板配色变量化（2026-11-09）

三处皮肤共享同一套面板色，集中在 `@Resources\theme-colors.inc`：

- 变量：`FaceGrad`（背景渐变）、`FaceStroke`（描边渐变）、`FaceSolid` / `FaceSolidStroke`（纯色版，给贴图选择器）
- 引用方式：主皮肤 `@Include=#@#theme-colors.inc`；子目录皮肤 `@Include=..\@Resources\theme-colors.inc`（`#@#` 在子目录会指向不存在的 `settings\@Resources`）
- **inc 文件必须带 `[Variables]` 段头**。缺了它变量不会加载，Rainmeter 只报 `Shape: LinearGradient has invalid parameters: #FaceGrad#`，不会提示 include 失败——很容易误判成渐变写法不支持变量
- 主皮肤和配置页的 `[Panel]`：`1=#FaceStroke#`、`2=#FaceGrad#`；贴图选择器：`Fill Color #FaceSolid#`
- **配置页的 Panel 几何由 `Settings.lua` 的 `layoutBottom()` 动态覆盖**，必须同步改成 `Fill LinearGradient 2 | Stroke LinearGradient 1`。原来写的是 `Fill LinearGradient 1`（把描边渐变当填充），会让整页变浅色，和主面板对不上

当前值（改这里，三处一起变）：

- `FaceGrad = 180 | 24,32,58,188;0 | 38,54,98,196;0.55 | 28,72,116,196;1`
- `FaceStroke = 180 | 96,150,230,60;0 | 70,120,210,40;0.55 | 90,200,240,60;1`
- `FaceSolid = 24,32,58,250`；`FaceSolidStroke = 96,150,230,60`

其他显示元素也已变量化（同日完成）：

- 语义色：`TextMain=235,238,245`、`TextDim=220,215,240`、`Accent=176,158,255`、`AccentBlue=120,220,255`、`ButtonBg=72,87,150`、`CardBg=28,38,70`、`CardBg2=44,49,74`、`LineWhite=255,255,255`、`PickerStroke=150,140,220`
- ini 里直接用 `#TextMain#` 这类引用；`Note.lua` 用全局表 `C`（`boot()` 里 `loadPalette()` 从 `SKIN:GetVariable` 读），`Settings.lua` 用 local 表 `PAL`
- **`Note.lua` 的 `C` 不能用 `local`**：文件级 local 已到 200 上限，再加就整份编译失败
- **`SKIN:GetVariable` 不能取址**：写成 `local g = SKIN:GetVariable` 会报 `function arguments expected`，冒号方法只能立即调用
- 保留不动的：`THEMES` 四套主题色（卡片随主题切换）、`SWATCH_COLORS` / `SWCOL`（主题色选择器）、`RightClip` 遮罩色 `72,87,150`（是乘色，不是按钮色）

### 4.4 容器与渐变

- 容器子米特坐标**相对容器**，且必须显式写 `Container=<名字>`。
- 容器 alpha **乘**到子米特上 —— 跑马灯的两端淡出就是这么做的：`RightClip` 用 180° 渐变（透明→不透明→透明）当遮罩。
- LinearGradient 角度：**0=右→左，90=下→上，180=左→右，270=上→下**。水平渐隐用 180。

### 4.5 Tooltip

- 系统绘制，字体颜色不可改，无淡入淡出，阈值由系统管（实测 <250ms）。
- 选项：`ToolTipText`（必填）、`ToolTipTitle`（单行）、`ToolTipIcon`（Info/Warning/Error/Question/Shield 或 .ico）、`ToolTipType=1`（气泡）、`ToolTipWidth`（默认 1000，超出折行）、`ToolTipHidden=1`（不弹）。
- **要批量临时关提示，用 `ToolTipHidden=1`**，不要清空 `ToolTipText`（后者要存原文、容易漏米特）。

### 4.6 Mouse 测量

- `Measure=Mouse` 的 `RequireDragging=1`：**只有 `Start` 之后才监听**，`Stop` 后静默；`RequireDragging=0` 是常开。
- 多个 Mouse 测量可以共存且互不干扰 —— 实测 A 启用时 B 完全静默。
- 所以「左键一套、右键一套」可以拆成两个测量，各自在手势开始时 Start。
- 合成鼠标事件（`mouse_event`）对 `*DragAction` 不可靠，涉及拖拽的验证一律让用户真手拖一次。

---

## 5. 布局与状态机

### 5.1 布局入口

`layout()` 每次都会：

1. `buildColumns()` 重算列
2. 算 `w/h`（由 `cols`、`rows` 推）
3. `!SetVariable SW/SH/rows/cols`
4. 重画 `Panel`、标题、日历、卡片、新建区

窗口用 `DynamicWindowSize=1`，所以米特超出 `SW/SH` 时窗口会自动变大，但 `Panel` 背景不会 —— 这正是「收藏栏可以探出背景」的实现方式。

### 5.2 buildColumns 的 dragging 判定

```lua
local dragging = (dragIdx and dragIdx >= 1) or NEW_DRAG or (FAVUI and (FAVUI.drag or FAVUI.dropping))
if not dragging then cols = lastCol end   -- 非拖拽才裁掉尾部空列
```

- 拖拽中必须跳过裁剪，否则「新建列」刚建就被裁掉。
- 收藏拖出落点期间要保留 `FAVUI.dropping = true`，落点算完清掉，再 `layout()` 一次让空列裁掉、窗口缩回。

### 5.3 收藏页状态

`FAVUI` 是全局表，字段：

| 字段 | 含义 |
|---|---|
| `ui` | `normal` / `fav` / `favDrag` |
| `hover` | 当前悬停行（0 基，-1 无） |
| `rect` | 每行矩形（供选中框/色点定位） |
| `panel` | 面板矩形（判断松手是否在面板内） |
| `drag` | 正在拖的收藏行 |
| `dropping` | 落点计算中 |
| `moved` | 是否真的移动过（8px 阈值） |
| `dimTop` | 面板打开时把新建区/★压暗 |
| `skipUntil` | 打开后 0.35s 内忽略悬浮 |

行索引是 **0 基**（`FavShape0..5`），收藏列表索引是 **1 基**，换算时 `idx = favPage * FAV_PER + 行号 + 1` —— 这里错过一次，点第一条改到第二条。

---

### 5.4 坐标口径（左上角 vs 中心，改布局前必读）

这套皮肤里所有"位置"都是**左上角**，但落点判定曾经按**中心**算过，整整偏了一格。两种口径别混。

**1. 皮肤坐标**

- `$MouseX$` / `$MouseY$`（`RelativeToSkin=1`）= 相对皮肤左上角
- `Meter:GetX(true)` / `GetY(true)` 的 `true` 是"相对皮肤"（不是相对屏幕），和上一条同一套
- 所以 `downX = meter:GetX(true) + mx` 得到的已经是皮肤坐标，可以直接和 `$MouseX$` 相减

**2. 卡片位置（左上角）**

```lua
-- slotPos(r, c)：第 r 行第 c 列卡片的左上角
margin + fixedW() + (c-1)*(cardW+gapX),  header + (r-1)*pitch
```

- `pitch` 是行距（含 gapY），`cardH = pitch - gapY`
- 第 r 行覆盖 `header+(r-1)*pitch` 到 `header+(r-1)*pitch+cardH`

**3. 鼠标 → 行号：用 floor，不要 +0.5**

```lua
-- 正确：鼠标落在哪一行
local r = math.floor((y - header) / pitch) + 1

-- 错误：+0.5 是"离哪个行边界近"，会让鼠标在本行下半部时被判到下一行
local r = math.floor((y - header) / pitch + 0.5) + 1
```

| 语义 | 写法 | 用在 |
|---|---|---|
| 落在哪一格 | `floor(...) + 1` | 拖拽落点、预览框 |
| 插到某条边界 | `floor(... + 0.5) + 1` | 分隔线附近的"插到中间" |

> 2026-11-08 踩过：用 `+0.5` 算常驻区落点，鼠标在本行下半部时 fr 多 1，预览框整体偏下一格。

**4. 常驻区：屏幕行 vs 数组位**

| 概念 | 含义 | 公式 |
|---|---|---|
| 屏幕行 | 卡片显示在第几行 | `k - FIXUI.scroll`（k = 第几个 pin） |
| 数组位 | 第几个 pin 便签（给 `insertPinnedAt` 用） | `屏幕行 + FIXUI.scroll` |

- `fixedSlotAt(y)` 返回**数组位**
- 画预览框要换算回屏幕行：`header + min(rows-1, max(0, slot - scroll - 1)) * pitch`
- 上限是 `rows-1`，不能是 `rows` —— 否则预览框会被画到可视区下面那张
- 屏幕行的上限还要夹到 `min(rows, n) + 1`，`n = fixedCount()`

**5. 自查清单**

改任何位置相关代码前，问三句：

1. 这个坐标是**皮肤**还是 **Meter 内**？（`GetX(true)` 已经是皮肤坐标，别再减一次 Meter X）
2. 这个数是**左上角**还是**中心**？（`slotPos` 全是左上角）
3. 我要的是"落在哪一格"还是"插到边界"？（floor vs round）

---

### 5.5 拖拽落点判定（每个分支都要先比对起点）

拖拽结束时，落点由几个变量共同决定，来源不同、语义也不同：

| 变量 | 来源 | 语义 |
|---|---|---|
| `dragCol` | `targetCellSmart(x, y)` | 落在第几列（时间列） |
| `dragTo` | 同上返回的 r | 该列第几行 |
| `hintFixed` | `fixedHit(x, y)` | 落点在常驻区（**优先于** dragCol） |
| `hintFixedSlot` | `fixedSlotAt(y)` | 常驻区的**数组位**（已含 scroll） |

**通用规矩：先算起点，再处理落点。**

```lua
-- 时间列：先算 from 现在在哪一格
local fc, fr = nil, nil
for cc = 1, cols do
    for rr, idx in ipairs(colLists[cc] or {}) do
        if idx == from then fc, fr = cc, rr end
    end
end
if fc and dragCol == fc and dragTo == fr then
    -- 原地不动，什么都不做
end
```

**为什么必须显式排除「原地」**

1. `targetCellSmart` 判的是鼠标**当前所在格**。卡片中心在垂直方向天然偏下，所以拖每列第 1 行、几乎没动时，落点会算成第 2 行
2. 交换分支的条件是 `list[pos] ~= from`，**落点等于起点时会掉进 `else`**，而 `else` 的语义是「移到末尾」——表现出来就是和下面那张换位

**2026-11-08 踩过**：拖每列最上方那张，稳定和下面一张换位。两条原因同时成立（落点被算成下一行 + 起点没排除）。

**三个落点分支的写法模板**

```lua
if fc and dragCol == fc and dragTo == fr then
    -- ① 原地：不动
elseif list[pos] and list[pos] ~= from then
    -- ② 交换：两张内容互换（日期、来源一起换）
else
    -- ③ 换列/换日期：改 date，再把它移到数组末尾
end
```

**自查清单**

写任何 drop 分支前问：

1. 这个分支的「原地」是什么？我排除了吗？
2. 落点正好等于起点时，会不会掉进某个 `else`？
3. 常驻区和时间列的落点变量是两套（数组位 vs 行列），我用对了吗？

---

## 6. 工作流

### 6.1 改代码

1. 先 `ffn_git.py status`，工作区必须干净；不干净先提交
2. 备份要动的文件（`.bakNN`，编号递增，别覆盖）
3. **用函数名/整段锚点替换，不要原地 mutate 正在遍历的字符串** —— 这条踩过两次，第二次把 150 个卡片节点写坏了
4. 改完跑 `python _luaparse.py`，`parse OK` 才继续
5. 脚本里 `assert` 失败 = 文件没写入，**别直接提交**

### 6.2 验证三件套

- **回读文件**：`_readnotes.py` 看数据、`_rows.py` 看日期
- **看日志**：`%APPDATA%\Rainmeter\Rainmeter.log`，过滤 `NoteLua`
- **截图**：先枚举窗口 rect，再 `CopyFromScreen`；窗口位置会被操作挪走，每次重新取

### 6.3 提交

```powershell
python "C:\Users\朱门高悬云帆\.dsh\im\ffn_git.py" commit "一句话说明改了什么"
```

本地仓库，无 remote。提交前确认 `parse OK`、无 TODO 残留。

---

## 7. 工具

| 工具 | 用途 |
|---|---|
| `ffn_git.py` | dulwich 包装：`status` / `commit "msg"` / `log N` |
| `pack_rmskin.py` | 打包：自动排除 `.git`、`*.bak*`、`.broken`，重置个人数据，可传 Description |
| `skin_visual_regress.py` | 视觉回归：`baseline` 记基线，`check` 比差异（0 无变化 / 1 有变化） |
| `_luaparse.py` | 用 `luaparser` 检查 Note.lua 语法 |
| `_readnotes.py` / `_rows.py` | 读 notes.txt 概览 |
| `_balance.py` | 查 DeepSeek 余额 |
| `qq_send.py` | 发 QQ 文本（官方机器人 API） |

测试皮肤：`Skins\_HoverTest\`（Test.ini~Test8.ini），悬浮、命中、tooltip、双 Mouse 测量都在里面验过。

---

## 8. 踩坑档案（按类别）

**编码/文件**
- 写 ini 时边遍历边替换同一个字符串 → 节点错位，150 个卡片节点被吞；从 git 快照整块捞回
- assert 失败仍提交 → 空提交

**布局**
- 收藏面板被遮罩压暗 → `FavMask` 被 pop 到末尾，节点顺序错
- 新列刚建就消失 → `buildColumns` 的 dragging 判定
- 空列不裁、窗口不缩 → 落点后没用非拖拽身份 `layout()` 一次

**拖拽**
- 收藏后少一张卡 → `layout()` 跳过 `dragIdx` 那张，收藏前必须先清 `dragIdx`
- 轻拖就取消收藏 → 缺 8px 阈值 + 面板内松手判定
- 拖不进新列 → 建列后 `targetCell` 返回 `c=-1`，要重算；而且不能拿旧坐标重算（列宽变了）

**交互**
- 打开面板时选中框停在第一条 → 遮罩上误绑了 `hoverFav(0)`
- 只第一条能悬浮 → 悬浮动作只加到了 `FavText`，没加 `FavShape`
- 取消拖动后文字回弹成高亮 → `newZoneReset()` 没认 `dimTop`
- tooltip 滞留 → 遮罩挡不住命中，要用 `ToolTipHidden`
- ★ 呼吸不生效 → 根因是 Calc 返回小数，颜色分量非法；`DynamicVariables=1` 本身没问题（2026-10-26 更正）

**贴图自动发现（2026-10-28）**
- Rainmeter 的 Lua 没有可靠的目录枚举，所以用 @Resources\img.ps1 扫 img\*.png 写成 list.txt（GBK，一行一个去扩展名的文件名）
- 皮肤启动时 imgReload() 读 list；缺 list 则自动 imgScan()；右键「扫描贴图」手动刷新
- cycleImg() 顺序取自 IMG_LIST，因此往目录里丢 PNG + 扫描就能扩展，无需改代码
- 单张建议 ≤160px、透明 PNG；12 张 160px 合计约 105 KB

**String 的描边与阴影（2026-10-28 实测）**
- StringEffect=Border（四周描边）与 =Shadow（右下 1px 投影）都有效，**不受字体限制**
- 但两者都是**固定 1px**，不随 FontSize 缩放：10px 字号下很微妙
- 可见度取决于 FontEffectColor 与底色的对比：红色描边一眼可见，黑色描边只让字略粗；深色 + 半透明（如 12,10,24,190）在深色卡片上**等于没有**
- 想要更清楚的文字：FontWeight 比描边有效 —— 400 正常、500 略粗、600 明显粗（YaHei UI 有真实字重），只改一个数，零成本

**Container 坐标机制（2026-10-28 实测更正）**
- 容器节点自身的 X/Y 是子节点坐标的**原点**；子节点 X=0 就落在容器 X/Y 上
- Shape 容器还要看 Shape 里的起始点 x1,y1：子节点只有落在 x' > x1 && y' > y1 的部分才会被画出来，并按形状裁剪
- FatFishNote 的 CardClipN 没设 X/Y（=0,0），Shape 矩形用绝对坐标写 → **子节点坐标就是绝对坐标**，可以直接用卡片的 x/y 算
- 上一版「容器坐标偏移 306」的结论是错的：当时量的是**另一张卡**上的图，误把别的卡坐标当成了当前卡

**图片素材（2026-10-28）**
- 素材来源：dsh-pet v0.3.7（MIT，PC2005-cloud），其 ssets/webm 有 106 段动画、ssets/memes 26 张、ssets/pic/notify-*.png 6 张透明图标
- 抽帧：imageio-ffmpeg 装好后 fmpeg -ss <t> -i x.webm -frames:v 1 -pix_fmt rgba out.png；帧是 **640×360 黑底无 alpha**
- 抠底：按亮度 key（LO=10 / HI=34 + 0.6px 高斯羽化），再裁 bbox、缩到 160px
- 压缩：quantize(colors=160, FASTOCTREE) 后 40KB → 9KB，观感几乎无损
- 成品在 @Resources\img\（12 张，105KB），NOTICE.txt 保留 MIT 声明

**AI 投递接口（2026-10-28）**
- 外部程序/AI 只通过 @Resources\ai_drop.txt 投递：YYYY-MM-DD\t名称\t正文，GBK，行内不能有制表符/换行
- 皮肤每 4.8 秒轮询，导入后清空文件（清空=成功）；日期窗口 [今天-4, 明天]，上限 30 条
- **同名 + 同日 = 更新正文**（2026-10-28 起），不再新增重复条目
- 契约文档：@Resources\AI接口.md（UTF-8，随包发布）

**发布打包（2026-10-28）**
- pack_rmskin.py：python pack_rmskin.py <skin_dir> <out.rmskin> <name> <author> <version> [load_ini]，会自带清理（删 *.bak*、*.log、*.broken，把 notes/favorites 换成空模板）
- 发布前把个人数据换成中性内容：
otes.txt 清空、utonote.txt 改示例规则、city.txt 与 ini 的 city/lat/lon 改北京、settings.ini 显示城市、Note.lua 默认 autoRules、Settings.lua 默认城市与规则
- 包里不放 nime.txt、nime.log、*.bak*、
egress/
- 验证方式：解包到 Skins\FatFishNoteTest 独立配置，激活看能否加载与自动生成便签，确认后删除



**做内容（视频/文案）时的教训（2026-10-30）**

- **口径不统一，数字会自己打脸**：同一次测量我先报「工作集 40.9/47.2/75.6」，后来任务管理器显示 34/40/44 —— 前者是总工作集且混进了反复装卸皮肤后未归还的内存。对外只用一个口径：**任务管理器「内存」列（私有工作集）**，并写明「重启后等待 20 秒」。
- **绝对化表述是弹幕靶子**：「占用低到看不到」「不会崩」「我都能帮你」这类句子，观众里只要有一个懂行的就会拆。改成「感觉不到它在跑」「崩了数据在文件里」这种可验证的说法。
- **数据卡要有证据层**：纯数字卡片像「我算给你看」，嵌一张任务管理器实拍（并把对应行高亮）才算实测。截图裁剪要含表头，否则读者不知道哪一列是内存。
- **文案的抽象句必须被具体句兜住**：结尾那句「我的每一个时刻都是现在」之所以不油，是因为下一句是「文件由我写，由你带到下一个现在」。抽象后面接抽象，就是文学腔；接事实，才是表达。
- **人称要立表**：这片子里「我=肥鱼、他=使用者、你=观众」，混一次就出戏。写文案时先把三列写死，再逐段检查。
- **AI 视角的可信度来自限制**：「我看不见结果，只能靠使用者告诉我」「那半边，我替不了」——这类句子比任何自夸都值钱，也是最难被替代的部分。

**容器层级与 alpha（2026-10-29 实测）**
- `Container` 的子米特**跟随蒙版的层级**绘制：画在蒙版之后、紧跟蒙版；与子米特自身在 ini 里的位置无关。同一蒙版下的多个子米特之间仍按各自节顺序叠
  - 验证：`_HoverTest\Test61.ini`，Mask(白) → Other(蓝) → Child(绿, Container=Mask)，中心像素为蓝，说明子米特在 Other 之下
- **半透明会伪装成层级问题**：星标 `FontColor` 的 alpha 掉到 110 时，下层橙色网格线透上来，肉眼看起来就是「线压在星星上」。判断层级必须先让两边都不透明
- 反过来，要「让特效在星星下面」，正确做法是保证**蒙版**排在星星之前；把子米特挪位置没用
- 渐变定义不在 `Gradient=` 关键字里，而是 meter 内的 `1=` / `2=` 两行；按 `Gradient` 搜文件会 0 命中

**底板与渐变（2026-10-29 订正）**
- 整块板子的背景是 `[Panel]`，不是 `[FavPanel]`（后者才是收藏面板）。`[Panel]` 在 ini 里的默认尺寸是 559×375，运行时被 `layout()` 改成整板 `w×h` —— **别拿 ini 默认尺寸当证据，也别按名字猜用途**
- Rainmeter 的命名渐变定义不在 `Gradient=` 关键字里，而是 **meter 内的 `1=` / `2=` 两行**，`Shape=... | Fill LinearGradient 2 | ... | Stroke LinearGradient 1` 按编号引用。按 `Gradient` 关键词搜文件会 0 命中
- 当前板子配色：`[Panel]` 的 `1=`（描边渐变）和 `2=`（填充渐变）决定背景；卡片颜色在 `Note.lua` 的 `THEMES`（`card` / `stroke` / `accent` / `head`）；`THEMES` 里的 `g1` / `g2` 是死代码，无引用
- 判定某个 meter 是什么，看两样：谁在运行时改它的 `Shape`（grep `setOpt('<名字>'`），以及它出现过什么尺寸，不要只看名字

**改图后正文消失（2026-10-28，真因）**
- 真因不是滚动状态，而是**坐标写法**：Text / Img 在 Container 下必须用**相对容器原点**的坐标，我一直在用绝对坐标，靠「蒙版米特恰好在 0,0」侥幸成立
- 蒙版原来的写法是 Shape=Rectangle <x+1>,<y+hh+1>,... 全部绝对坐标，米特却在 0,0 → 容器原点到底是米特位置还是 shape bbox 有歧义，改图/重排时就会漂
- 正确做法：**蒙版米特定位 + 局部 shape**
  - setOpt('CardClip'..m,'X', x+1)、'Y', y+hh+1
  - Shape=Rectangle 0,0,(cardW-2),(cardH-hh-2),rr
  - 子米特坐标 = 卡片内相对坐标：正文 X=14-1、Y=40-(hh+1)-off；插图 X=cardW-86-1、Y=cardH-90-(hh+1)
- 空白便签的居中大图分支要把 Container 清空，否则会继承上一次的相对坐标系
- 有正文 + 有插图时，正文 W 要减 78px，否则插图压在字上
- 教训：容器里凡是「看起来能显示」的坐标，都要问一句「是不是碰巧原点对上了」
- **Container 的坐标原点会「粘住」旧值**（2026-10-28 实测）：容器的 `X/Y` 改了之后，已经存在的子米特不会自动按新原点重算，`GetOption X/Y` 仍是新值，但 `GetX/GetY` 还是「旧原点 + 偏移」。典型症状：给某张卡加插图后，正文被插图的位置带偏（`Text5` 选项 13,13，实际落在 459,455 = 293+153+13）。
  修法：**设完子米特的 X/Y 之后，再断言一次 `Container`，然后 `!UpdateMeter`**。只重新设同一个值就够（不需要先清空），实测能当场纠正。
  最小验证：`_HoverTest\Test60.ini`（容器 + 两个子米特）里坐标是稳的，说明机制本身没问题，漂移只在「容器先被建出来、位置后改」的运行时路径上出现。
- **滚动相关的三处 Y 也要跟着改**：`autoReset`、`autoScrollTick`、`noteScroll` 原来都用 `Card:GetY() + 40`，改相对坐标后必须换成 `rnd(40*scale) - (rnd(26*scale)+1) - 偏移`，否则悬浮滚动会失效（文字不动，或复位后停在半截）

**改图后正文消失（旧记录：滚动状态，次要）**
- 现象：在贴图面板换图/换色后，卡片正文不可见，标题与插图正常；刷新皮肤后恢复
- 定位：Text 在 Container 下运行时坐标漂移（GetOption X/Y 仍是 306/184，GetX/GetY 变成 752/362），文字被蒙版裁掉
- 触发条件：该卡处于换图那一刻的滚动/自动滚动状态中，layout() 在旧偏移上重排
- 修法：
esetScrollFor(i) 清 SCROLL[note] 与 AUTO（m/seg/off），在 imgPickTick、cycleTheme、cycleImgAt 里 layout 之前调用
- 经验：任何「面板改了卡片外观」的路径，收尾都应是 
esetScrollFor(i) → writeAll() → layout()

**自动便签锁定（2026-10-28）**
- 冲突根源不是 utoGen() 覆盖，而是 clearAllSkips() **把所有 src=auto 的便签整条删掉再重建** —— 用户改过的正文/配色/贴图会一起没
- 解法：notes 加第 8 个可选字段 locked；用户改动 auto 便签（正文/标题/配色/贴图）时置 1
- clearAllSkips() 保留锁定项并日志提示「有 N 条已锁定的自动便签，本次未更新」
- utoGen() 的同名同日判重不再区分来源，避免改名后重复生成
- 解析改为**按 tab 切分**而不是长正则，后续加字段更安全（正则加一个分组就可能整行匹配失败）
- 数字型 src（0/1/2…）不解决覆盖问题，且破坏兼容与可读性；要溯源时用字符串 uto:monthly:2 更合适

**数据安全**
- **写 `notes.txt` 的新功能先在 `_HoverTest` 用副本验证**：`notes.test.txt` 做数据源，跑通「读—改—写—重载」再接主皮肤（2026-10-28 番剧便签直接上主皮肤，启动早期把 14 条写成 1 条）
- **新增定时器任务的写入路径前，先问一句：它会在 `boot()` 完成前跑吗？** 番剧便签的 `AnimeTimer` 每 2 秒调一次 `animeImport()`，而后者「找不到就新建一条再写盘」；启动早期 `notes` 还是空表，于是 14 条被写成 1 条。修法是 `BOOTED` 门禁 + 空表/骤减拒写
- `writeAll()` 必须有下界保护：内存条数为 0、或比磁盘少 3 条以上时**拒绝写盘**（2026-10-28 上午两次把 10 条用户便签写成 4 条，靠 `notes.txt.bak55` 恢复）
- 写盘前会自动把当前文件备份到 `@Resources\notes.bak`，但**只保一份**；重要改动前手动 `notes.txt.bakN`
- 自动便签会重生成、用户便签不会 —— 数据变少时先看 `src=user` 的行还在不在

**TextEdit 与热键（实测）**
- `Meter=TextEdit` 需要 `AccurateText=1`，提交值只存在于 `OnSubmitAction` 的 **`[$Input]`**
- **清空输入框只能用 `!TextEdit:Clear "名字"`**（或 `!TextEdit:SetText`）；`!SetOption <meter> Text ""` 对原生控件**无效**，看起来设了空值但控件里还是旧文字
- **同一配置目录下多个皮肤注册同一个 `HotKey` 会互相抢占**：`_HoverTest` 里的测试皮肤激活时抢走了 `CTRL+ALT+N`，主皮肤的热键就没反应了。测完必须 `!DeactivateConfig _HoverTest`
- **热键从别的应用触发时，键盘不会自动进皮肤**：Rainmeter 没有「激活自己窗口」的 bang，`!ZPos 1` 只改层级不改前台。要真的收到按键，必须外部脚本抢前台：`@Resources\focus.ps1`（先 `keybd_event` 按一下 Alt 解锁，再 `AttachThreadInput` + `SetForegroundWindow`；直接调 `SetForegroundWindow` 会被 Windows 前台锁拒绝）
- **输入框一旦失焦就救不回来**：点框外任何地方 → `OnDismissAction` 触发；之后无论 `!TextEdit:Focus` 还是再点回输入框，都无法继续输入/提交。所以「输入框旁边的位置按钮」方案不可行，必须**先选位置、再弹框**
- 按钮动作在 `DISMISSED` 之后约 120ms 仍会执行，只是此时输入框已废
- `HotKey` 插件写法 `HotKey=CTRL ALT N` + `KeyDownAction=`，**全局生效**（皮肤失焦也能触发）
- **Lua 顶层调用 `SKIN:GetVariable` 会让脚本加载失败**，报错却是 `Script: File not valid`（像语法错），必须先怀疑顶层执行了 SKIN 调用

**Lua 200 个 local 上限（重要）**
- Lua 每个函数最多 **200 个 local 变量**；`Note.lua` 的文件级 chunk 已经顶到上限，再加一个 `local function xxx` 就**整个脚本编译失败**
- 症状极坑：Rainmeter 只报 `Script: File not valid`（看着像文件坏/语法错），实际是编译期 "too many local variables"，日志不会说原因
- 解法：新增辅助函数用**全局函数**（`function foo()` 而不是 `local function foo()`），不占 local 名额；函数内部的 local 不受影响
- 排查手段：把 `Note.lua` 复制到 `_HoverTest\NoteCopy.lua`，用最小皮肤加载，改一版测一版

**String 换行与 GBK**
- `ClipString=2` **只在空格/制表符处换行**，单词本身过长时整行裁掉，不拆词；`ClipString=3` 文档里不存在（实测等同不裁剪）
- 想拆无空格长串只能往文本里插断点，但**本皮肤文本是 GBK**，插 UTF-8 的零宽空格（E2 80 8B）会整句乱码 —— 只能对**纯 ASCII 片段**插普通空格
- 现有实现：`noteSoftBreak()`（全局函数），只在 token 长度 > 18 且全 ASCII 时每 12 字符插一个空格

**Lua 作用域**
- `local` 是文件作用域，**后声明的 local 在前面的函数里会解析成全局 nil**。两天内踩了三次：`layout`、`favOpen`、`locate`
- 新增 helper 前先确认它引用的每个 local 都已声明；否则写 `local foo` 前向声明 + `foo = function(...)`，或把 helper 挪到被引用函数之后
- 症状很好认：`attempt to call global 'xxx' (a nil value)`，且只在某条分支触发（其它分支不经过那条引用）

**Shape 修饰词**
- `StrokeDashes` 的数值是**线宽的倍数**，不是像素；断线周期 =（实长+空长）× 线宽
- 想让点阵规整，周期必须**整除格子尺寸**（例：格 16px、线宽 8、`1,1` → 周期 16 ✓）
- 一条连续路径跨格时断线相位会累积漂移；**每行做成独立 Path**（`Shape1..ShapeN` 各引用一行）可让相位每次重置
- `Path` 是 meter 上的**命名选项**，`!SetOption` 必须设在 meter 上（`!SetOption Ring1 P1 "..."`），不能直接写给 `P1`
- **遮罩要「对齐格心」必须同时处理两件事**：① `StrokeDashes` 从路径起点开始排，`0,2` 的第一个点落在格子边界，要加 `StrokeDashOffset 1`（half period）推到格心；② 圆心要用 `ox + (i+0.5)*cell`，不能用 `ox + i*cell`（那是线交点）
- 线宽不影响几何位置（描边以线为中心两侧扩展），但决定 dash 周期；顺序是：定线宽 → 周期=线宽×(实+空) → 周期整除格子 → 用 offset 对齐
- 当 `Container` 的遮罩要透出内容原色时，遮罩必须填**纯白**：容器颜色会乘到子 meter 上

**层级（绘制顺序）**
- meter 的先后只由节点顺序决定；浮层（进度条、落点预览、幽灵卡）必须放在被覆盖对象**之后**，否则被卡片盖住（2026-10-27 进度条被常驻区卡片挡住即此）
- 进度条这类贴边元素，X 要算进「卡片与分隔线之间的间隔」，不要压在卡片上

**鼠标坐标**
- meter 动作里的 `$MouseX$` / `$MouseY$` 是**相对该 meter** 的，不是相对皮肤；要比对皮肤坐标，必须先加上 `meter:GetX()/GetY()`（2026-10-28 进度条点击「时灵时不灵」即此）

**悬停区域**
- 多块相邻 hover 区不要靠「进入/离开」即时切换：跨区必然先 leave 后 over，会闪。稳妥做法是 leave 只记 `sawLeave`，由 tick 判定「离开且静默 >0.3s」才隐藏，任何进入都清掉 `sawLeave`
- 离开处理器里不能再调用「进入」函数：`fixedHalf('')` 内部调了 `fixedEnter()`，等于一离开就重新进入，浮层永远不隐藏。leave 必须走独立的 `fixedHalfLeave()`
- 「只在悬停时出现」的浮层，其可点击区域必须自己也参与 hover 判定（`FixedHover`），否则一靠近就消失
- 相邻 hover 区域之间不要留缝：鼠标跨过 1px 空隙也会触发 `MouseLeaveAction`；兜底做法是给隐藏加 0.3–0.4s 宽限期

**动画/滚动**
- 自动滚动移开鼠标不复位 → `autoReset()` 只还原了 `Text`，没还原 `Y`；**凡是改过 X/Y/W/H 的效果，复位时几何与内容要一起还原**
- 无缝循环错行 → 单段高度不能用「行数×行高」估（估 75px，实测 133px），必须用探针米特（`W` 同正文、`ClipString=2`、**不写 H**）读 `GetH()`

**验证**
- 用记忆里的窗口坐标截图/点击 → 全部对不准，白花半天；每次重新枚举 rect
- 合成鼠标测拖拽 → 不可靠，交给用户真手

---

## 9. 待办与待定

- **收藏库滚动（已做）**：6 行固定、滚轮步进 1、右侧进度条（只显示不可拖）、▲▼ 整页翻；索引统一走 `FAVUI.scroll`（0 基），拖动用 `FAVUI.dragAbs` 记绝对下标
- **右键拖动复制便签（已做）**：`MeasureMouseR` + `COPY`，位移 <6px 视为单击→开设置
- **便签正文滚动（已做）**：容器裁剪 + 像素偏移；滚轮步长 = 行高；最大偏移由 `wrapLines` 估算（CJK=1fs、西文=0.55fs），与真实字体有微小误差
- **去掉 settings 里三处 `!Refresh`**：换 `reloadAll()` 之类的重载函数

---

## 10. 接手清单

1. 读这份总纲，再读 `~/.dsh/肥鱼日记.md`、`AGENTS.md`
2. `ffn_git.py status`，确认工作区干净、看最近三条提交
3. 启动皮肤，截一张图当基线
4. 读 `notes.txt`，确认便签数量与日期
5. 问清楚这次要改什么，**先给方案再动手**

---

## 11. 更新日志

| 日期 | 内容 |
|---|---|
| 2026-10-26 | 初版：整理 10/25–10/26 两天的全部经验（收藏库、拖拽、悬浮、tooltip、Mouse 测量、buildColumns、数据格式） |
| 2026-10-26（下午） | 更正 §4.3：`DynamicVariables=1` 下节变量颜色确实会刷新，之前失败是小数不合法；同步改掉踩坑档案那条 |
| 2026-10-26（下午） | 正文滚动定稿：**每卡一个独立裁剪蒙版 `CardClip0..29`**（白色填充、紧跟在本卡之后、不隐藏），`Text` 挂 `Container=CardClip{m}`；卡片外框恢复正常 |
| 2026-10-27（下午） | 固定区列头加「常驻」标签（与「今天/明天」同一排，y=topBar+12）；翻页箭头由 ±18px 改为各向内 20px（贴住时间列边缘） |
| 2026-10-27（下午） | 布局第 2/3 步：`pin` 字段 + 拖进/拖出固定区；翻页箭头改为对称夹住时间列（`prevX`/`nextX` 由时间列左右缘推算）。坑：`hintFixed` 状态位没在 `beginDrag`/`drop` 入口清，残留会把后续普通拖拽误判成固定 |
| 2026-10-28（凌晨） | 进度条交互增强：hover 区拆成上下两半（`FixedHoverTop/Bottom`），点击方向由 meter 决定、不再算坐标；悬停那半的 ▲▼ 用 `sin` 跳动并提亮，复用 `AutoTick`（32ms）驱动 |
| 2026-10-28（下午） | 素材：从 dsh-pet 抽帧 318 张，挑 12 张抠底压缩进 @Resources\img\ |
| 2026-10-28（下午） | AI 对接：iTick 同名同日改更新；新增 AI接口.md；发布包重打（66 KB） |
| 2026-10-28（中午） | 发布 v1.6 包：清个人数据、换中性示例、README 重写、FatFishNote_v1.6.rmskin（63 KB） |
| 2026-10-28（上午） | 长英文串换行：`noteSoftBreak` 对纯 ASCII 长 token 插空格；顺带发现 Lua 200 local 上限会让脚本整份报 `File not valid` |
| 2026-10-28（上午） | 热键快记上线：`CTRL+ALT+M` 常驻区首位、`CTRL+ALT+N` 今天列，右键菜单两条入口；实测 TextEdit 失焦不可恢复，故不采用「框旁按钮」 |
| 2026-10-28（上午） | 根因修复：番剧 `animeImport` 加 `BOOTED` 门禁，启动早期不写盘；坑档新增「定时器写入路径」一条 |
| 2026-10-28（上午） | 数据救援：便签被写空（内存解析异常→写盘），从 bak55 恢复 14 条；`writeAll` 增加空表/骤减双保险；删掉不可点击的色点，改标题条换色 |
| 2026-10-28（上午） | 番剧便签落地：`@Resources\anime.ps1` 抓 yuc.wiki 当日段（`<!--周X-->` 分段 + `imgtext4/imgep/date_title_`），写 GBK `anime.txt`；`AnimeTimer` 每 2s 检查，日期不符则启动脚本，抓到后生成「今日番剧」便签并去重 |
| 2026-10-28（早） | 常驻区便签恢复悬浮反馈（`cardXY` 统一取位）；修时间列悬浮被 `cardXY`/`locate` 声明顺序打断；踩坑档新增「Lua 作用域」一类 |
| 2026-10-28（凌晨） | 收藏星标加涟漪反馈：点阵遮罩（`0,2`+offset 1 对齐格心）+ 三层圆环，点击触发 1.1s 后自动收起 |
| 2026-10-28（凌晨） | 进度条点击不稳定修复：`$MouseX$/$MouseY$` 是 meter 相对坐标，`fixedBarClick` 里先换算成皮肤坐标；文档新增「鼠标坐标」一类 |
| 2026-10-27（深夜） | 常驻区进度条：点击轨道上下两半各翻一页（步长 = `ROWS`），离开加 0.35s 宽限期避免跨缝隙闪烁；新增 `FixedHover` 透明 hover 条补齐卡片与分隔线之间的判定空隙 |
| 2026-10-27（深夜） | 常驻区进度条增强：点击轨道上下翻页（`fixedBarClick`）、溢出时轨道两端显示 ▲▼、加宽命中区 `FixedBarHit`；Shape 的 Triangle 语法点数写错导致不渲染，箭头改用 String |
| 2026-10-27（夜） | 常驻区进度条：meter 移到卡片之后、X 移进空隙；踩坑档新增「层级」类 |
| 2026-10-27（夜） | 术语统一：新增「0.5 术语表」（原生概念用英文、自有概念定中文、命名约定）；skin 变量 `rows`/`cols` 改名 `ROWS`/`COLS` |
| 2026-10-27（夜） | 修复正文自动滚动复位：`autoReset()` 补回 `Text` 的 `Y`；踩坑档新增「动画/滚动」类两条 |
| 2026-10-27（傍晚） | 常驻区滚动：`FIXUI.scroll` + `fixedScroll/fixedEnter/fixedLeave`，进度条 `FixedBar`/`FixedBarThumb` 只在悬停且有溢出时显示。坑：`layout`/`favOpen` 都是后声明的 local，前面的函数必须前向声明 `local layout`、面板状态走 `favIsOpen()` |
| 2026-10-27（傍晚） | 常驻区落点改为「最靠近的插入位」：`fixedSlotAt(y)` + `insertPinnedAt(k)`；卡片/新建区/收藏栏三条路径统一。坑：幽灵卡拖拽横向 clamp 上界仍按时间列算，卡在第二列左缘（316px），改为整板宽。整理便签：节气口径/热键快记/番剧便签 入常驻区，删掉「便签固定」「收藏滚动」两条已实现便签 |
| 2026-10-27（下午） | 布局改造第 1 步：左侧固定区骨架。`fixedW()` = 卡宽+间距；`baseW`/`slotPos`/`layout` 的 w/`targetCell` 四处同步加了偏移；新增 `FixedBg`/`FixedTitle`/`FixedDivider` 三个米特。窗口宽度 560 → 824 |
| 2026-10-27（中午） | 新建便签加 `boardYOk(y)` 判定：拖到列头以上不落点（`targetCell` 会把 r 钳到 1，所以必须在调用方挡）；实测标题区失焦 = 不加，正文区 = 加 |
| 2026-10-27（凌晨） | 缩放灵敏度修正：原公式 `(dx+dy)/500` 斜拖会翻倍，改为 `(dx+dy)/2/1000`；实测 500px 垂直拖动 = +0.25 倍 |
| 2026-10-26（深夜） | 缩放磁吸：`SNAP` 六档，1.0/1.5 半径 0.04（回滞 1.8 倍），其余 0.02；吸附时 `ScaleTip` 显示百分比、手柄变紫；松手写盘。实测 1.00/1.25 均能吸住并持久化 |
| 2026-10-26（晚） | 自动便签文案修正：每周观感改为「写一段对肥鱼的看法和感受」（原来误写成「对小帆的看法」）；顺带发现 **`#autoskip` 无法手工清除** —— 解析时只要某日期存在 `src=auto` 的便签，保存就会重新写回该日期的 autoskip（Note.lua 第 1011 行），要验自动生成必须先移走当天的自动便签 |
| 2026-10-26（下午） | 容器蒙版的多矩形必须用 `Combine` 合成：`Shape=Rect1 \| Fill ...` + `Shape2=Rect2` + `Shape3=Combine Shape \| Union Shape2`，多区域才能同时生效（Test16 三块内容全显示）；**独立图元直接并列只有第一块生效**（Test13/14） |
| 2026-10-26（下午） | 实测三条容器规则：①**容器本身不绘制**（拿 Card 当容器会让卡片消失）②**一个容器只能带第一个内容米特**，第二个内容不显示 ③内容在**容器所在位置**绘制，蒙版必须紧跟内容之前，且蒙版颜色会**乘**到内容上（用白色） |
| 2026-10-26（下午） | 卡片节点顺序改为 `Card→Text→Head→Name→Del`（标题栏画在正文之上且不透明），否则滚动时正文会压住标题 |
| 2026-10-26（下午） | 便签正文滚动：**容器裁剪可行**（Test10 实测：子米特 H=2000 被 200×100 的容器裁住，窗口不变大）。最终实现 = `Text` 挂 `Container=Card`、H=4000、像素偏移 `noteScroll`；`wrapLines` 只用来估算最大偏移。先前「容器会撑窗口」的结论是误判（窗口变高来自行数） |
| 2026-10-26（下午） | 收藏条目右键拖动：拖到列=复制到板子（收藏保留），拖进新建区=删除；`MeasureMouseR` 改为 `dragMouseR/dropMouseR` 分发（便签复制 / 收藏复制） |
| 2026-10-26（下午） | 新增右键拖动复制：`MeasureMouseR`（独立鼠标测量，RequireDragging=1）+ `COPY` 状态；右键单击（没移动）仍开设置。实测 `R_DRAG` 可正常触发（之前失败是合成事件节奏问题） |
| 2026-10-26（下午） | 修：`NEW_DRAG`（拖出新便签）越界时 `targetCell` 返回 c=-1 却没重算，导致「列建出来了、便签没落下去」；现在和卡片拖拽一样先 `layout()` 再算一次 |
| 2026-10-26（下午） | 修：面板本体（FavPanel/FavTitle/FavHint/FavEmpty）加空动作 `favNop()` 吃掉点击，避免点面板空白处被判定为「点外部」而关闭 |
| 2026-10-26（下午） | 进度条可拖（`favBarDown/Move/End`，按像素换算行数）+ 点轨道跳转（`favBarJump`），思路参考 nbdock 的 TrackDot（只读未改） |
| 2026-10-26（下午） | 修：关闭收藏面板时同步隐藏 `FavBar/FavBarThumb`（favHideAll 漏项） |
| 2026-10-26（下午） | 收藏库改为滚动：`FAVUI.scroll` + `FavBar/FavBarThumb` 进度条 + 滚轮绑定 16 个节点；新增 `favReload()` 供外部改完文件后重载 |
| 2026-10-26（下午） | 代码清理：删掉 34 个零引用函数（调试类 dump*/diag*/wincheck/previewLong、废弃的 favRight/menuTheme*/menuCity1-6/swShow/swHideNow/select/todayTime/charLen/fitChars）、合并 2 处重复定义、加文件头区块说明。Note.lua 2508 → 2367 行；视觉回归 0 命中格子。**保留清单**：autoDump/autoWrite/reloadAuto/reloadNotes/clearAllSkips/favCount 等命令行接口 |
| 2026-11-09 | 面板配色变量化：三处皮肤背景统一到 `theme-colors.inc`（见 §4.3.1）；修 `Settings.lua` 把描边渐变当填充的旧写法 |
| 2026-11-09（下午） | 语义色变量化：文字/强调/按钮/白线/描边全部进 `theme-colors.inc`；`Note.lua` 加全局 `C` + `loadPalette()`，`Settings.lua` 加 `PAL`；坑：冒号方法不能取址、`C` 表定义被批量替换污染 |

---

## 12. 今日复盘（2026-10-28）

### 交付

| 项 | 结果 |
|---|---|
| 常驻区/时间列悬浮 | 修好（`cardXY` 统一取位） |
| 番剧便签 | 上线：抓 yuc.wiki、GBK 缓存、每日一次、可关 |
| 热键快记 | 上线：`Ctrl+Alt+M` 常驻区、`Ctrl+Alt+N` 今天 |
| 数据事故 | 14 条被写成 4 条，从 `bak55` 恢复，加 `BOOTED` 门禁 + 双保险 |
| 插图素材 | 抽帧 318 张，挑 12 张抠底压缩进 `img/` |
| 贴图面板 | 阶段 1/2/4/5/6 完成，阶段 3（滚动）待图变多再做 |
| 发布包 | v1.6（含 AI 接口文档） |

### 今天最贵的三条

1. **Lua 200 local 上限**：加 `local function` 会让整份脚本编译失败，报错却是 `Script: File not valid`。今天栽了两次。
2. **容器坐标与裁剪**：子节点坐标相对容器；Shape 容器要 `x' > x1 && y' > y1` 才画。我误判过一次（量错卡）。
3. **写盘下界保护**：空表或骤减时拒绝写盘 —— 这是今天数据事故的直接护栏。

### 流程上的改进

- 「写 `notes.txt` 的新功能先在 `_HoverTest` 用副本验证」已经写进纪律，今天之后应该不会再出数据事故
- 截图前先查窗口 rect，今天好几次截空是因为窗口挪了/框位置变了
- 改 Lua 一律先 `_luaparse.py`，再看日志；`File not valid` 优先怀疑 local 超限和顶层 SKIN 调用

