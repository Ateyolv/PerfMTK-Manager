# PerfMTK Manager 简体中文版

此分支基于 JUANIMAN 的 PerfMTK Manager，增加简体中文界面与固定个人签名的 GitHub Actions 构建。保留原作者署名、原项目许可证和底层模块行为。

## 使用

- 中文系统首次启动默认简体中文；也可在 Settings → Language 中选择“简体中文”。
- 保留英文、西班牙语，手动选择会保存。繁体中文系统使用同一份简体翻译。
- 首页、温控、应用规则、配置编辑与提示文案已翻译。CPU/GPU/FPSGO 等技术标识、调频器值、配置键、应用名称、底层原始日志保持原样。
- Android 快捷设置磁贴跟随系统语言，不与 App 内单独选择的语言绑定。
- 仍需安装原版 PerfMTK 模块并授予 Manager Root 权限；汉化不会为设备增加硬件能力。

## 安装与升级

- APK 保留包名 `com.perfmtk.manager`，但签名与官方版不同，不能直接覆盖官方 APK。首次安装前，请备份 App 配置，再卸载官方 Manager；无需卸载 PerfMTK 模块。
- 之后使用同一把签名密钥，以及更高的 versionCode，即可覆盖升级中文版本。
- App 更新检查指向 Ateyolv 的 Fork，无 Release 时不提示。当前工作流只上传构建附件，不自动发布 Release。

## 云端构建

[工作流](https://github.com/Ateyolv/PerfMTK-Manager/blob/chinese-localization/.github/workflows/chinese-apk.yml)在 `chinese-localization` 分支推送时运行，也支持手动运行。

工具链固定为 Ubuntu 22.04、Java 17、Flutter 3.44.0、Android API 36、Build Tools 36.0.0 和 NDK 28.2.13676358。上游依赖锁文件要求 Flutter ≥3.44.0 / Dart ≥3.12.0，因此未使用旧 README 提及的 Flutter 版本，也未重新解析或升级依赖。

在仓库 Settings → Secrets and variables → Actions 中配置：

| 类型 | 名称 | 内容 |
|---|---|---|
| Secret | SIGNING_KEYSTORE_BASE64 | 固定 JKS 密钥库的 Base64 文本 |
| Secret | SIGNING_STORE_PASSWORD | 密钥库密码 |
| Secret | SIGNING_KEY_ALIAS | 密钥别名 |
| Secret | SIGNING_KEY_PASSWORD | 私钥密码 |
| Variable | SIGNING_CERT_SHA256 | 签名证书 DER 的 SHA-256，小写无冒号 |

密钥和密码不得提交到仓库，不得输出到日志，不得上传到构建附件。请在安全位置离线备份，且不要每次构建重新生成。Base64 不是加密。

构建前运行静态分析、全部 Flutter 测试与原生翻译一致性检查；通过后才临时恢复签名材料。Release 构建缺少密钥时明确失败，不退回 Debug 签名。构建号为 `1000 + GITHUB_RUN_NUMBER`。

成功后在 Actions → 对应运行 → Artifacts 下载 `PerfMTK-Manager-zh-运行编号`。附件包含 APK、SHA-256 校验值和公开构建记录，保留 30 天。

验收还检查 APK 签名、固定证书、包名、构建号、ARM64 运行库和非 Debug 属性。云端通过不等于已在每一款手机上实测：实机安装、Root 授权、G90T 的硬件控制仍需设备端确认。
