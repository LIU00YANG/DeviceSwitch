# SignPath 免费代码签名配置指南

SignPath Foundation 为开源项目提供免费的 Authenticode 代码签名。本仓库已内置
GitHub Actions 工作流（`.github/workflows/release.yml`），完成以下一次性配置后，
每次打 tag 即可自动构建、签名并发布 Release。

## 第一步：注册并申请

1. 打开 https://signpath.io/ 注册账号（可用 GitHub 账号登录）
2. 创建一个 **Organization**，类型选择 **Open Source**（SignPath Foundation 的免费计划，
   如页面提示需申请审批，按其引导提交开源项目信息即可，需要提供本仓库的公开地址）
3. 在 Organization 中添加 **Trusted Build System → GitHub.com**

## 第二步：创建 Project

1. 新建 **Project**，命名如 `DeviceSwitch`，记下它的 **Project slug**
2. Trusted build system 选择刚才添加的 GitHub.com，并填写本仓库地址
3. **Artifact Configuration**：新建一个配置，内容如下（zip 内所有 exe 都做 Authenticode 签名）：

```xml
<artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
  <zip-file>
    <file-set>
      <include path="*.exe" />
      <pe-sign>
        <authenticode-sign />
      </pe-sign>
    </file-set>
  </zip-file>
</artifact-configuration>
```

4. **Signing Policy**：编辑 `release-signing` 策略，关联上面的 Artifact Configuration，
   并允许来自 GitHub 的构建。记下策略的 **slug**（通常为 `release-signing`）

## 第三步：创建 API Token

1. 在 Organization 的 **Users** 中添加一个用户（或用你自己），角色授予该项目的 **submitter** 权限
2. 为该用户创建 **API Token**，复制保存

## 第四步：配置仓库密钥

在本仓库页面：**Settings → Secrets and variables → Actions**

| 类型 | 名称 | 值 |
|---|---|---|
| Secret | `SIGNPATH_API_TOKEN` | 第三步的 API Token |
| Variable | `SIGNPATH_ORGANIZATION_ID` | Organization 设置页的 Organization ID |
| Variable | `SIGNPATH_PROJECT_SLUG` | 第二步的 Project slug |
| Variable | `SIGNPATH_SIGNING_POLICY_SLUG` | 第二步的策略 slug（如 `release-signing`） |

## 第五步：发布一个签名版本

```bash
git tag v1.0.0
git push --tags
```

Actions 跑完后，Releases 页面会出现 `DeviceSwitch-signed.zip`，
里面的 exe 都带有数字签名（右键 exe → 属性 → 数字签名 可验证）。

## 常见问题

- **签名请求失败，提示 artifact 不存在**：确认 `upload-artifact` 步骤用的是 v4 及以上，
  且 `github-artifact-id` 引用的是该步骤的 `outputs.artifact-id`
- **Artifact configuration 校验失败**：`upload-artifact` 默认产出 ZIP，
  所以配置根元素必须是 `<zip-file>`
- **Organization ID 在哪**：Organization → Settings 页面顶部
