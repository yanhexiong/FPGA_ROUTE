# Vivado 安装指南

## 目的

Vivado 是 AMD（原 Xilinx）的 FPGA 开发工具，用于完成综合、实现、生成比特流以及通过 JTAG 下载等步骤。本路线自 S1-05 起使用 Vivado 与 Vitis（PS 配置与裸机程序），S3 的 HLS 使用同一安装包中的 Vitis HLS。

本指南涵盖两类使用环境，读者按自身情况选择其一：

| 环境 | 适用情形 |
|---|---|
| Windows | 日常使用 Windows 的个人电脑 |
| Ubuntu | 实体机安装的 Ubuntu，或在 KVM 等虚拟机中运行的 Ubuntu |

## 版本

本路线暂定使用 **2023.1**，Vivado、Vitis、PetaLinux 版本保持一致。选择该版本的原因是：2023.1 是 Vitis AI 3.5 与 DPU 4.1 官方验证过的工具版本，S6 部署 DPU 时须使用与之匹配的版本。若 2023.1 在使用中出现无法解决的问题，再整体升级到更新的版本，届时本指南将同步更新。

两块开发板的芯片 XCZU5EV（EdgeBoard FZ5D）与 XCZU4EV（AXU4EVB-E）均属于 Vivado 免费版（Vivado ML Standard Edition）支持的器件，UG973 的 Supported Devices 一节列出了这两款器件；免费版自 2016 版起无需许可证文件。安装完成后，可用本目录的检查脚本加以确认，见「安装验证」。

开发板厂商（如 MYIR）的手册与示例工程多基于 Vivado/Vitis 2020.1。这些示例工程不宜在 2023.1 中直接沿用，应依据手册中的参数在 2023.1 中重新建立，或在 Vivado 中升级 IP 后再使用。

## 系统要求

| 项目 | Windows | Ubuntu |
|---|---|---|
| 操作系统 | 官方支持 Windows 10 专业版或企业版（20H2、21H1、21H2、22H2），以及 Windows 11（21H2、22H2）。Windows 10 家庭版不在支持列表中 | 官方支持 Ubuntu 22.04 LTS 与 22.04.1 LTS（64 位），以及 20.04、18.04 系列。22.04 的后续小版本未列出，通常可以使用。Ubuntu 24.04 不在支持列表中，见「Ubuntu 24.04 的补充说明」 |
| 内存 | 建议 16 GB 及以上 | 建议 16 GB 及以上；使用虚拟机时，分配给虚拟机的内存建议不少于 12 GB |
| 磁盘 | 建议预留 100 GB 以上 | 建议预留 100 GB 以上 |
| 网络 | 采用在线安装程序时需要联网 | 同左 |
| 账号 | 下载前须注册 AMD 账号 | 同左 |

**路径限制（两类环境通用）：** 安装目录、工程目录及其上级目录中，不得包含空格或中文字符。Windows 用户名为中文时，不应将工程放在用户目录（如桌面、文档）下，而应使用 `C:\fpga\` 这类纯英文路径。路径不合规会导致综合或实现阶段出现难以定位的错误。

**后续阶段的说明：** S5 使用的 PetaLinux 只能在 Linux 上运行。使用 Windows 的读者，最晚在进入 S5 之前须准备一个 Ubuntu 环境（例如 KVM 或 VirtualBox 虚拟机）。此外，S1 的仿真实验（Icarus Verilog、cocotb）以 Ubuntu 为准编写，Windows 用户可在 WSL2 中完成。

## 下载

1. 访问 AMD 下载页面 <https://www.xilinx.com/support/download.html>，在左侧版本列表中选择 **2023.1**。
2. 根据操作系统选择安装程序：
   - Windows：*AMD Unified Installer for FPGAs & Adaptive SoCs 2023.1: Windows Self Extracting Web Installer*；
   - Linux：*AMD Unified Installer for FPGAs & Adaptive SoCs 2023.1: Linux Self Extracting Web Installer*。
3. 登录 AMD 账号，按要求填写出口管制信息后下载。

上述安装程序为在线安装程序（web installer），体积较小，安装时按所选组件联网下载。网络条件较差时，可改为下载同一页面中的完整安装包（SFD），其体积在百 GB 量级，下载后可离线安装。

## 安装步骤（两类环境通用）

1. 启动安装程序（启动方式见下一节），使用 AMD 账号登录。
2. **选择产品**：选择 **Vitis**。Vitis 安装包包含 Vivado、Vitis 与 Vitis HLS，本路线 S1–S4 所需的工具一次安装完成。
3. **选择器件**：在器件列表中只保留 **Zynq UltraScale+ MPSoC**，取消其余器件系列。器件系列是安装体积的主要来源，只保留所需系列可大幅减少下载量与磁盘占用。后续如需其他器件，可再次运行安装程序追加。
4. **选择安装目录**：Windows 默认为 `C:\Xilinx`，Linux 默认为 `/tools/Xilinx`，均可保持默认。
5. **JTAG 驱动**：Windows 安装程序中有安装电缆驱动（cable drivers）的选项，应勾选；Linux 须在安装完成后手动安装，见下一节。
6. 开始安装。所需时间取决于网络与磁盘速度，通常为一至数小时。

## 各环境的具体操作

### Windows

1. 以管理员身份运行下载的 `.exe` 安装程序，按「安装步骤」完成安装。
2. 若安装时未勾选电缆驱动，可在安装目录下找到 `Vivado\2023.1\data\xicom\cable_drivers\nt64\` 中的驱动安装程序补装。
3. 安装完成后，可从开始菜单启动 **Vivado 2023.1**（图形界面）或 **Vivado 2023.1 Tcl Shell**（命令行）。

### Ubuntu 22.04（实体机或 KVM 虚拟机）

1. 安装依赖库。Ubuntu 22.04 缺少 `libtinfo5` 时，安装程序会长时间停在 *Generating installed device list* 一步：
   ```bash
   sudo apt update
   sudo apt install libtinfo5 libncurses5 build-essential
   ```
2. 运行安装程序。安装到默认目录 `/tools/Xilinx` 需要管理员权限：
   ```bash
   chmod +x Xilinx_Unified_2023.1_*_Lin64.bin
   sudo ./Xilinx_Unified_2023.1_*_Lin64.bin
   ```
   若不使用 `sudo`，须在安装程序中将安装目录改为当前用户有写权限的目录，例如 `~/Xilinx`。
3. 安装 JTAG 电缆驱动，安装后须重新插拔 JTAG 下载器：
   ```bash
   cd /tools/Xilinx/Vivado/2023.1/data/xicom/cable_drivers/lin64/install_script/install_drivers
   sudo ./install_drivers
   ```
4. 配置环境变量。每次使用前须在终端中执行以下命令，也可将其追加到 `~/.bashrc`：
   ```bash
   source /tools/Xilinx/Vivado/2023.1/settings64.sh
   ```
   之后在终端中运行 `vivado` 即可启动图形界面。

**KVM 虚拟机的补充说明：**

- 分配给虚拟机的内存建议不少于 12 GB，处理器核数不少于 4 个。内存不足时，实现阶段可能因内存耗尽而失败。
- JTAG 下载器须直通给虚拟机：在 virt-manager 中打开虚拟机设置，选择「添加硬件 → USB 主机设备」，选中 JTAG 下载器对应的 USB 设备。直通后，宿主机将无法访问该设备。
- 若不便直通，也可以在连接开发板的机器上运行 `hw_server`，再在虚拟机中的 Vivado Hardware Manager 里通过网络连接该机器。

### Ubuntu 24.04 的补充说明

Ubuntu 24.04 不在 Vivado 2023.1 的官方支持列表中，但通常可以安装和使用，前提是补装 24.04 软件源中已不再提供的兼容库 `libtinfo5` 与 `libncurses5`：

1. 在 <https://packages.ubuntu.com/jammy/libtinfo5> 与 <https://packages.ubuntu.com/jammy/libncurses5> 页面，下载 amd64 架构的 `.deb` 文件（jammy 即 Ubuntu 22.04）。
2. 安装这两个文件：
   ```bash
   sudo apt install ./libtinfo5_*_amd64.deb ./libncurses5_*_amd64.deb
   ```
3. 其余步骤与 Ubuntu 22.04 相同。

在非官方支持的系统上遇到问题时，AMD 不提供技术支持。若出现无法解决的问题，应改用 Ubuntu 22.04 环境，或按「版本」一节的说明整体升级工具版本。

## 安装验证

### 1. 确认版本

- Windows：打开 **Vivado 2023.1 Tcl Shell**，执行 `version -short`，应输出 `2023.1`。
- Ubuntu：在已执行 `settings64.sh` 的终端中运行 `vivado -version`，第一行应为 `Vivado v2023.1 (64-bit)`。

### 2. 运行检查脚本

本目录下的 `vivado_check.tcl` 依次完成以下检查：

1. 输出 Vivado 版本；
2. 列出已安装的 XCZU5EV 与 XCZU4EV 器件，确认器件库安装完整；
3. 以 XCZU5EV 为目标，对 `s1/01_first_tb/counter.v` 执行一次综合，确认免费版许可可以覆盖该器件。

运行方法：

```bash
cd <仓库目录>/setup
vivado -mode batch -source vivado_check.tcl
```

Windows 用户在 **Vivado 2023.1 Tcl Shell** 中先以 `cd` 进入 `setup` 目录（路径分隔符写作 `/`），再执行 `source vivado_check.tcl`。

脚本最后输出 `CHECK PASSED` 即为全部通过。运行过程中生成的日志文件（`vivado*.jou`、`vivado*.log`）可以删除。

### 3. 确认 JTAG 驱动

将 JTAG 下载器连接到计算机后，在 Vivado 中选择 **Open Hardware Manager → Open Target → Auto Connect**。开发板上电时，左侧应列出板上的器件。此步骤可留待 S1-05 上板时进行。

## 常见问题

- **安装程序停在 *Generating installed device list*。** Ubuntu 上缺少 `libtinfo5`，按对应小节补装后重新运行安装程序。
- **综合时报告无法获取许可证（license）。** 所选器件不在免费版的支持范围内，或安装时未选择相应的器件系列。运行检查脚本，确认器件已列出。
- **综合或实现阶段出现无法解释的文件或路径错误。** 检查安装目录与工程目录中是否含有空格或中文字符。
- **Hardware Manager 找不到下载器。** Windows 上检查电缆驱动是否已安装；Ubuntu 上检查是否执行了 `install_drivers` 并重新插拔；虚拟机中检查 USB 设备是否已直通。
- **实现阶段进程意外退出。** 通常是内存不足。关闭其他程序，或增加虚拟机的内存分配。

## 参考资料

| 资料 | 出处 | 阅读重点 |
|---|---|---|
| AMD, *Vivado Design Suite User Guide: Release Notes, Installation, and Licensing*（UG973），v2023.1 | [docs.amd.com](https://docs.amd.com/r/2023.1-English/ug973-vivado-release-notes-install-license) | Supported Operating Systems 一节（支持的操作系统）；Supported Devices 一节（免费版支持的器件） |
| AMD 下载页面 | [xilinx.com/support/download.html](https://www.xilinx.com/support/download.html) | 2023.1 安装程序 |
