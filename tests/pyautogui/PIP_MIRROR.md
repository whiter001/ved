# Pip 全局镜像配置（Tsinghua）

本项目使用以下命令将 pip 全局镜像切换为清华源，并信任该域名（适合国内网络环境）：

- 设置全局镜像：
  python3 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
- 设置信任域名：
  python3 -m pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

如需查看当前配置：
  python3 -m pip config list

如需恢复默认源：
  python3 -m pip config unset global.index-url
  python3 -m pip config unset global.trusted-host
