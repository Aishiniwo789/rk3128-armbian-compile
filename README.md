# RK3128 打印机服务器 Armbian 镜像

## 特性
- 基于 Armbian 24.5.1 (Ubuntu Jammy) 构建
- 专为 RK3128 电视盒子优化
- 预装完整打印服务 (CUPS + HPLIP + SANE)
- 支持 USB 和网络打印机
- 集成 Avahi 打印机发现服务
- Web 管理界面: http://设备IP:631
- 最小化系统，节省存储空间

## 硬件支持
- CPU: Rockchip RK3128 四核 Cortex-A7
- RAM: 512MB-1GB DDR3
- 存储: 板载 eMMC (通常 8GB)
- 网络: 百兆以太网 + 板载 WiFi
- USB: 2个 USB 2.0 接口
- 视频输出: HDMI + AV 复合视频
- **注意**: 没有 TF 卡槽，只能刷入 eMMC

## 刷机步骤

### 1. 准备工具
- RK3128 电视盒子
- USB Type-A 公对公数据线
- RKDevelopTool v2.4 或更高版本

### 2. 进入 MaskROM 模式
1. 断开盒子电源
2. 短接 eMMC 的 CLK 和 GND 引脚（或查找对应主板短接点）
3. 连接 USB 到电脑
4. 松开短接，设备应被识别为 MaskROM 设备

### 3. 刷写镜像
```bash
# 在 RKDevelopTool 中:
1. 加载固件: 选择生成的 .img 文件
2. 执行擦除操作
3. 执行写入操作
4. 重启设备
