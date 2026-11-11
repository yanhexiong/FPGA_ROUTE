/*
 * S1-05 PS 侧 RUN 指示灯程序（Vitis 裸机，standalone）。
 * 规格见同目录 README.md「第三步」。本文件给出框架，TODO 处由实验者完成。
 *
 * 在 Vitis 中的用法：以 hello_world 模板新建应用工程，
 * 将模板生成的 helloworld.c 的内容替换为本文件的内容。
 *
 * 所需 API 的声明与示例：在 Vitis 中展开 Platform 工程 → BSP → gpiops 驱动，
 * 打开 Import Examples，其中的 xgpiops_polled_example 给出了完整调用顺序。
 */
#include <stdio.h>
#include "xparameters.h"
#include "xgpiops.h"
#include "xil_printf.h"
#include "sleep.h"

#define RUN_LED_PIN   42      /* PS MIO42：RUN 指示灯 D46 经三极管 Q2 的驱动端 */
#define HALF_PERIOD_US 500000 /* 灯状态每 0.5 s 翻转一次，即 1 Hz 闪烁 */

int main(void)
{
    XGpioPs      gpio;
    XGpioPs_Config *cfg;
    u32          level = 0;
    u32          n     = 0;

    xil_printf("\r\nFZ5D PS GPIO test: RUN LED on MIO%d\r\n", RUN_LED_PIN);

    /* TODO 1：查找 GPIO 控制器的配置并初始化 gpio
     *         （XGpioPs_LookupConfig、XGpioPs_CfgInitialize；设备号为 XPAR_XGPIOPS_0_DEVICE_ID） */

    /* TODO 2：将 RUN_LED_PIN 设为输出方向，并使能其输出
     *         （XGpioPs_SetDirectionPin、XGpioPs_SetOutputEnablePin） */

    while (1) {
        /* TODO 3：将 level 写到 RUN_LED_PIN（XGpioPs_WritePin），
         *         通过串口打印当前计数 n 与 level，
         *         调用 usleep(HALF_PERIOD_US) 延时，再翻转 level 并使 n 加 1 */
    }

    return 0;
}
