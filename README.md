# 南京工业职业技术大学校园网自动登录脚本

适用于 `NIIT-WIFI` 校园网。脚本会自动连接 Wi-Fi，并完成 Portal 认证。

已包含 `login.exe`，普通 Windows 电脑不需要安装 Python。

## 快速使用

1. 下载本项目或 release 压缩包。
2. 解压到一个固定目录，不建议放在微信临时文件夹里。
3. 双击 `一键初始化.bat`。
4. 按提示输入校园网账号和密码。
5. 测试完成后，输入 `Y` 安装自动登录。

账号后缀按运营商填写：

```text
校园用户：学号，不加后缀
电信：学号@dx
联通：学号@lt
移动：学号@cmcc
```

例如移动账号：

```text
2300000000@cmcc
```

## 自动登录方式

安装后，Windows 登录用户时会自动运行。

优先使用计划任务 `CampusAutoLogin`。如果当前电脑权限不允许创建计划任务，安装脚本会自动改用 Windows 启动文件夹快捷方式。

自动流程：

1. 连接 `NIIT-WIFI`
2. 等待网络就绪
3. 请求 `https://aaa.njuit.edu.cn:802/eportal/portal/login`
4. 验证是否真正能访问外网

## 手动测试

在项目目录打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\connect_and_login.ps1
```

如果失败，把同目录生成的 `login.log` 发给维护者排查。

## 文件说明

- `一键初始化.bat`：双击使用的入口
- `setup.ps1`：初始化账号密码、测试、安装自动启动
- `connect_and_login.ps1`：连接 Wi-Fi 并执行登录
- `install_startup_task.ps1`：安装计划任务或启动文件夹快捷方式
- `login.exe`：免 Python 可执行文件
- `login.py`：源码
- `config.njuit.portal-login.json`：配置模板

## 隐私提醒

初始化后会生成 `config.json`，里面保存校园网账号和密码。

不要把自己的 `config.json`、`login.log` 上传到 GitHub，也不要发给别人。
