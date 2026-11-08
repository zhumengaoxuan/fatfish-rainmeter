# Rainmeter 5.0 Shape 计量器完整参考（中文整理）

> 依据：Rainmeter 5.0 官方手册 <https://docs-v5.rainmeter.net/manual/meters/shape/>（2026 年抓取）
> 你手里的 `ShapeMeter.pdf` 是 **4.0.0 r2746** 的中文翻译，5.0 新增的内容它没有，文末有差异清单。

---

## 0. 一句话理解 Shape

`Meter=Shape` 里可以放任意多个 `Shape` / `Shape2` / `Shape3` … 对象；
每个对象 = **形状类型 + 参数**，后面用 `|` 接任意数量的**属性修饰符**和**变换修饰符**。
所有坐标都是**相对计量器左上角**的，单位是**设备无关像素（DIP，可为小数）**。

```ini
[MeterShape]
Meter=Shape
Shape=Rectangle 0,0,100,50 | Fill Color 0,0,0,255 | StrokeWidth 4 | Stroke Color 255,255,255,255
```

- 修饰符可省略、可任意顺序，但必须写在形状定义**之后**
- 多个 `Shape_N_` 按**数字顺序**绘制，序号大的盖在上面
- 默认填充白色 `255,255,255,255`，默认描边 1px 黑色

---

## 1. 形状类型

### 1.1 Rectangle

```
Rectangle X,Y,Width,Height[,RadiusX[,RadiusY]]
```

| 参数 | 必填 | 说明 |
|---|---|---|
| X / Y | ✓ | 相对计量器的左上角 |
| Width / Height | ✓ | 宽高 |
| RadiusX / RadiusY | | 圆角半径；只写一个则四角同半径 |

```ini
Shape=Rectangle 0,0,100,50
Shape=Rectangle 0,0,100,50,10
Shape=Rectangle 0,0,100,50,20,5
```

### 1.2 Ellipse

```
Ellipse CenterX,CenterY,RadiusX[,RadiusY]
```

**注意**：从中心向外画，`CenterX/CenterY` 是圆心；要留出左上空间，否则会被皮肤边界裁掉。

```ini
Shape=Ellipse 50,50,50
Shape=Ellipse 50,50,50,25
```

### 1.3 Line

```
Line StartX,StartY,EndX,EndY
```

### 1.4 Arc

```
Arc StartX,StartY,EndX,EndY[,RadiusX[,RadiusY[,RotationAngle[,SweepDirection[,ArcSize[,ShapeEnding]]]]]]
```

| 参数 | 默认 | 说明 |
|---|---|---|
| RadiusX / RadiusY | 自动 | 椭圆半径 |
| RotationAngle | 0 | 正负角度，绕起终点中点旋转两个虚拟椭圆 |
| SweepDirection | 0 顺时针 | 1 = 逆时针 |
| ArcSize | 0 小弧 | 1 = 大弧 |
| ShapeEnding | 0 不闭合 | 1 = 自动补线闭合 |

前面的可选参数想跳过时用 `*` 占位：

```ini
Shape=Arc 3,200,203,200,100,100,0,0,0,0 | StrokeWidth 6
Shape=Arc 10,15,110,215,*,*,*,*,*,1 | StrokeWidth 6
```

### 1.5 Curve

```
Curve StartX,StartY,EndX,EndY,ControlX1,ControlY1[,ControlX2,ControlY2[,ShapeEnding]]
```

- 一组控制点 → 二次贝塞尔
- 两组控制点 → 三次贝塞尔

```ini
Shape=Curve 5,5,200,225,400,115,0 | StrokeWidth 6
Shape=Curve 5,5,215,120,40,130,160,15,0 | StrokeWidth 6
```

### 1.6 Path / Path1

路径必须写在**独立的命名选项**里，再在 `Shape=` 里引用：

```ini
[MeterShape1]
Meter=Shape
Shape=Path MyPath | StrokeWidth 2 | Stroke Color 41,4,2,255 | Fill Color 87,149,212,255
MyPath=20,0 | LineTo 150,0 | LineTo 170,20 | LineTo 170,60 | LineTo 150,80 | LineTo 20,80 | LineTo 0,60 | LineTo 0,20 | ClosePath 1
```

路径组成部分：

| 命令 | 说明 |
|---|---|
| `StartX,StartY` | 起点（必填） |
| `LineTo EndX,EndY` | 直线段 |
| `ArcTo …` | 弧段，参数同 Arc 去掉起点 |
| `CurveTo …` | 曲线段，参数同 Curve 去掉起点 |
| `SetRoundJoin 0/1` | 从此处起线段用圆角连接 |
| `SetNoStroke 0/1` | 从此处起不描边（不改变闭合性） |
| `ClosePath 0/1` | 1 = 补一条回到起点的线，闭合成形 |

**Path 与 Path1 的区别**：填充规则不同。

- `Path`：**even-odd（奇偶）** —— 射线穿过路径的段数为奇数则在内部
- `Path1`：**non-zero（非零环绕）** —— 左→右穿 +1、右→左穿 −1，结果非 0 在内部

自交路径（比如五角星、镂空）会明显不同，需要试。

### 1.7 Combine（布尔合并）

```
Combine Parent | Union Child | XOR Child2 ...
```

| 合并方式 | 结果 |
|---|---|
| `Union` | 并集 |
| `Intersect` | 交集 |
| `XOR` | 只保留不重叠部分 |
| `Exclude` | 从父形状中减去子形状 |

```ini
Shape=Rectangle 4,4,110,110,55
Shape2=Rectangle 54,54,80,80,10
Shape3=Combine Shape | Union Shape2
```

规则：

- **属性修饰符**（Fill、StrokeWidth…）由**父形状继承**；子形状和新合并形状上的属性修饰符**被忽略**
- **变换修饰符**先各自执行（子可以先 Rotate），合并后新形状还能再叠加变换
- 合并结果**永远是闭合形状**，开放式形状/路径会自动闭合
- 绘制顺序仍按 `Shape_N_` 序号

---

## 2. 属性修饰符（Attribute Modifiers）

### 2.1 Fill

默认 `Color 255,255,255,255`。三种写法：

```ini
Fill Color 255,0,0,255
Fill LinearGradient MyGradient
Fill RadialGradient MyRadial
```

**开放式形状（Arc/Curve 未闭合、Path 未 ClosePath）默认不填充**，可以用 Fill 强制填。

### 2.2 Stroke

默认 `Color 0,0,0,255`，同样支持 `Color` / `LinearGradient` / `RadialGradient`。

### 2.3 StrokeWidth

默认 `1`。**不是外描边**，而是沿轮廓居中：一半在内、一半在外。

- 奇数宽度会由 Direct2D 做半像素抗锯齿
- 形状贴着皮肤左上角（X=0 或 Y=0）时，一半描边会跑到皮肤外被裁掉 → 需要把形状或计量器往右下挪

### 2.4 端点 / 虚线（5.0 有，4.0 中文版没有）

| 修饰符 | 默认 | 取值 |
|---|---|---|
| `StrokeStartCap` | Flat | Flat / Round / Square / Triangle |
| `StrokeEndCap` | Flat | Flat / Round / Square / Triangle |
| `StrokeDashCap` | Flat | Flat / Round / Square / Triangle |
| `StrokeDashes` | 无 | `DashSize,GapSize[,DashSize,GapSize…]` |
| `StrokeDashOffset` | 0 | 以 StrokeWidth 为单位的偏移倍数 |

`StrokeDashes` 的数值是 **StrokeWidth 的倍数**，不是像素：

```ini
Shape=Rectangle 0,0,100,100 | StrokeWidth 4 | StrokeDashes 2,1.5
Shape=Rectangle 0,0,100,100 | StrokeWidth 4 | StrokeDashes 2,2 | StrokeDashOffset 1.0
```

点线：`StrokeDashes 0,2` + `StrokeDashCap Round`。

### 2.5 StrokeLineJoin

默认 `Miter,10.0`：

| 取值 | 说明 |
|---|---|
| `Miter[,MiterLimit]` | 尖角，超过 MiterLimit 后切平 |
| `Bevel` | 斜切角 |
| `Round` | 圆角 |
| `MiterOrBevel[,MiterLimit]` | 超限自动转 Bevel |

---

## 3. 渐变（Defining Gradients）

渐变必须定义在**命名选项**里，再被 Fill / Stroke 引用。

### 3.1 LinearGradient

```
MyGradient=Angle | Color ; Percentage | Color ; Percentage | ...
```

```ini
[MeterShape]
Meter=Shape
Shape=Rectangle 1,1,101,101 | Fill LinearGradient MyFillGradient
MyFillGradient=180 | 255,0,0,255 ; 0.0 | 0,255,0,255 ; 0.5 | 0,0,255,255 ; 1.0
```

**角度表（官方原文，最容易看错的地方）**

| Angle | 方向 |
|---|---|
| 0 / 360 | 右 → 左 |
| 90 | 下 → 上 |
| 180 | 左 → 右 |
| 270 | 上 → 下 |

> 也就是说：**水平渐变用 180 或 0，垂直渐变用 90 或 270**。
> 想左端透明右端实心（或反之），只能靠 0 / 180 调百分比顺序。

**为什么容易写反（两个语义陷阱）**

1. **角度指的是「轴指向」，不是「颜色推进方向」**：0° 的轴指向右，颜色却是**从右往左**铺开；于是「从左往右」要写 180。
2. **和 CSS 约定相反**：CSS `linear-gradient(90deg)` 是朝右（左→右），Rainmeter 的 90 是**下→上**。写过 CSS 的人凭手感直接套，必错。


百分比可以超出 0.0–1.0，超出部分不直接显示但会影响插值。

### 3.2 RadialGradient

```
MyRadial=CenterX,CenterY[,OffsetX[,OffsetY[,RadiusX[,RadiusY]]]] | Color ; Percentage | ...
```

- `CenterX/CenterY`：渐变椭圆中心相对形状中心的偏移（像素）
- `OffsetX/OffsetY`：渐变原点相对椭圆中心的偏移
- `RadiusX/RadiusY`：椭圆半径

```ini
Shape=Ellipse 50,50,50 | StrokeWidth 0 | Fill RadialGradient MyGradient1
MyGradient1=0,0 | 155,200,232,255 ; 0.0 | 6,46,75,255 ; 1.0
```

### 3.3 LinearGradient1 / RadialGradient1（5.0）

在关键字末尾加 `1`，参数完全相同，只是**换用另一种 gamma 校正插值**，过渡更亮或更顺滑，视配色而定。

### 3.4 渐变作遮罩的实战要点

Shape 计量器当 **Container** 时，容器自身的 alpha 会乘到子米特上。所以：

- 容器 `Fill` 用渐变 → 子内容按渐变的 alpha 渐隐
- 想让文字「两端渐隐、中间实心」，渐变 alpha 应当：`0 @ 左缘 → 255 @ 内边距 → 255 @ 右内边距 → 0 @ 右缘`，角度用 **180**
- 容器**不会**被绘制，只用于裁剪，所以渐变的颜色本身无所谓，**只有 alpha 起作用**

---

## 4. 变换修饰符（Transform Modifiers）

| 修饰符 | 默认 | 说明 |
|---|---|---|
| `Rotate deg[,AnchorX,AnchorY]` | 0 | 绕形状中心或指定锚点旋转，可负 |
| `Scale sx[,sy[,AnchorX,AnchorY]]` | 1.0,1.0 | 倍率缩放；负值可翻转（镜像） |
| `Skew degx[,degy[,AnchorX,AnchorY]]` | 0,0 | 倾斜 |
| `Offset dx[,dy]` | 0,0 | 平移（像素） |
| `TransformOrder 顺序` | Rotate,Scale,Skew,Offset | 调整变换执行顺序 |

- 锚点是**相对形状左上角**的像素坐标
- `Scale` **不影响 StrokeWidth**，描边永远是设定值
- 镜像：水平 `Scale -1.0,1.0`、垂直 `1.0,-1.0`、都翻 `-1.0,-1.0`
- `TransformOrder Scale,Rotate` 会把未列出的依次排到后面

---

## 5. Extend：修饰符复用

```ini
[MeterShapes]
Meter=Shape
Shape=Rectangle 0,0,100,50 | Extend MySharedModifiers, MyRotate1
Shape2=Rectangle 20,10,50,50 | Extend MySharedModifiers, MyRotate2
MySharedModifiers=Fill Color 0,0,0,255 | StrokeWidth 4 | Stroke Color 255,255,255,255
MyRotate1=Rotate 20 | Scale 1.5,0
MyRotate2=Rotate 45 | Scale 2.0,1.5
```

规则：

- 被引用的命名选项在同一 `[Section]` 内必须**唯一**
- **不能级联**（Extend 里不能再 Extend）
- 等价于把修饰符**插入**到 Extend 所在位置；重复定义时**后者生效（last wins）**

---

## 6. 鼠标检测

Shape 的鼠标命中**只看实际绘制出的实心像素**，不是计量器矩形：

- 形状伸出计量器 W/H 之外，**仍然可以点到**
- 同一个 `[Section]`（一个 Shape 计量器）**每种鼠标动作只能有一个**
- 想让不同形状响应不同动作 → 拆成多个 Shape 计量器

---

## 7. 设备无关像素（DIP）

形状的坐标/尺寸是 **DIP**，可以写 `10.25`、`0.754` 这种小数；
但计量器本身的 `X/Y/W/H` 仍是**整数像素**。

---

## 8. 常见坑（结合实际踩过的）

1. **W/H 不可写**：Shape 计量器的 `W/H` 由绘制内容算出，写 `W=100` 不会裁剪形状。
   要裁剪请用 `Container` 或 `ClipString`（后者只针对 String）。
2. **`Ellipse` 参数是 4 个**（圆心 + 两半径），少写半径会变成默认圆而不是报错。
3. **描边贴边被裁**：形状在 X=0/Y=0 且有 StrokeWidth，一半描边在皮肤外，看起来「左上细右下粗」。
4. **渐变角度**：`90` 是**下到上**（垂直），不是水平；水平用 `0` 或 `180`。方向搞反会让「左右渐隐」变成「上下渐隐」。
5. **Container 子米特坐标相对容器**：改位置只改容器 `X/Y` 或子节点相对坐标，混用绝对坐标会导致内容被裁没。
6. **Container 需要子米特显式写 `Container=<名字>`**，仅把 Shape 放在前面不会生效。
7. **Combine 会吞掉子形状的属性修饰符**，颜色/描边只能写在父形状上。
8. **Path 的 `LineTo/ArcTo/CurveTo` 终点不含**：0 到 100 实际覆盖 0–99 像素。
9. **开放式形状默认不填充**，要显式 `Fill`。
10. **`SetNoStroke` 不改变闭合性**，只影响描边，别拿它当「开口」。

---

## 9. 5.0 相对 4.x（你那份 PDF）的差异

| 项目 | 4.0 中文版 | 5.0 |
|---|---|---|
| `StrokeDashes` | 叫 `StrokeDashArray`，语义不同 | 按 StrokeWidth 倍数的 `Dash,Gap` 列表 |
| `StrokeStartCap` / `StrokeEndCap` / `StrokeDashCap` | 无 | 有（Flat/Round/Square/Triangle） |
| `StrokeDashOffset` | 无 | 有（StrokeWidth 倍数） |
| `Path1` | 无 | 有（non-zero 填充规则） |
| `TransformOrder` | 无 | 有 |
| `LinearGradient1` / `RadialGradient1` | 无 | 有（gamma 插值变体） |
| `Extend` | 有 | 有（规则更明确：不能级联、last wins） |
| 渐变角度表 | 有（180 描述为「左到左」，笔误） | 明确：0 右→左、90 下→上、180 左→右、270 上→下 |
| DIP 说明 | 无 | 有 |

> 结论：**5.0 手册确实覆盖了 Shape 的完整用法**，而且比你手上那份 4.0 翻译多出虚线端点、Path1、变换顺序、渐变变体等条目。

---

## 10. 速查小抄

```ini
; 基本矩形 + 圆角 + 渐变描边
Shape=Rectangle 0,0,200,80,12 | Fill Color 30,32,48,255 | StrokeWidth 2 | Stroke LinearGradient G1
G1=180 | 255,255,255,40 ; 0.0 | 255,255,255,200 ; 1.0

; 圆形
Shape=Ellipse 40,40,40

; 折线
Shape=Line 0,0,200,0 | StrokeWidth 1 | Stroke Color 255,255,255,30

; 虚线圆角框
Shape=Rectangle 0,0,200,80,12 | StrokeWidth 2 | Stroke Color 255,255,255,120 | StrokeDashes 3,2

; 布尔挖洞
Shape=Rectangle 0,0,100,100
Shape2=Ellipse 50,50,30
Shape3=Combine Shape | Exclude Shape2

; 容器遮罩（子米特需 Container=Mask）
[Mask]
Meter=Shape
Shape=Rectangle 0,0,170,32 | Fill LinearGradient MaskGrad
MaskGrad=180 | 0,0,0,0 ; 0.0 | 0,0,0,255 ; 0.06 | 0,0,0,255 ; 0.92 | 0,0,0,0 ; 1.0
```
