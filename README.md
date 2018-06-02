### 基于kubernetes部署gitlab-ce

> 由于gitlab授权需要配置到hapcloud oauth2,所以只能使用官方的镜像。该文档使用的是mysql数据库，postgresql无需构建镜像

#### 一、构建镜像

> 在使用mysql作为gitlab的数据库时,需要自行安装mysql的依赖和驱动包。

```
# 使用该目录下的Dockerfile构建镜像
docker build -t gitlab-ce:10.2.8-ce.0 .
```

- 镜像构建完成后可以使用以下环境变量配置自动备份

参数 | 描述
---|---
GITLAB_BACKUP_SCHEDULE | 设置自动备份。选项有：`disable`, `daily`, `weekly`,`monthly`或者`advanced`。 默认是`disable`即禁用；`daily`为每天进行备份；`weekly`为每周星期天备份；`monthly`为每月1号进行备份；`advanced`为全自定义，备份时间格式与cron相同。
GITLAB_BACKUP_TIME | 若选择备份策略为`daily`, `weekly`,`monthly`，自动备份的时间格式为HH:MM，默认是01:00；若选择备份策略为`advanced`，自动备份的时间格式为* * * * *，默认是00 01 * * *,即每天1点进行备份。
GITLAB_BACKUP_SKIP | 选项有：`db`, `uploads` (attachments), `repositories`, `builds`(CI build output logs), `artifacts` (CI build artifacts), `lfs` (LFS objects)，默认为`repositories`
GITLAB_BACKUP_EXPIRY | 备份的数据多久（单位：秒）后进行删除。不进行自动删除则设置为0, 开启自动备份功能，默认是7天后进行删除，即604800秒。

- 通过ConfigMap挂载gitlab.rb配置文件

通过ConfigMap将gitlab.rb挂载到`/opt/choerodon/paas/etc/gitlab.rb`，运行镜像时就会加载此文件。

#### 二、部署

##### 1.资源调整（若集群各节点资源充足可跳过此步）

> 由于gitlab运行需要大量的资源并且要保证其稳定性,不受到其他pod的影响,这里专们调整一台节点部署,这里我们选择了node5(4c16g)

- 节点准备

```
# 首先给node5节点打上标签
kubectl label nodes node5 gitlab="true"
# 对选好的节点上的pod进行驱赶
kubectl taint nodes node5 gitlab="true":NoSchedule
```

- 修改`kube-flannel`和`kube-proxy`的配置文件让其可以忍受所有的taint使其能够在node5上运行

```
# 查看kube-flannel和kube-proxy部署是否在此命名空间下
kubectl get daemonset -n kube-system
# 进行修改kube-flannel配置
kubectl edit daemonset kube-flannel -n kube-system
# 以下配置请配置在containers属性中，与containers的image属性平级
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
      - effect: NoSchedule
        operator: Exists

# 进行修改kube-flannel配置
kubectl edit daemonset kube-proxy -n kube-system
# 以下配置请配置在containers属性中，与containers的image属性平级
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
      - effect: NoSchedule
        operator: Exists
```

- 修改`gitlab/deploy.yml`文件

```
# 以下配置请配置在containers属性中，与containers的image属性平级
      nodeSelector:
        gitlab: "true"
      tolerations:
      - effect: NoSchedule
        key: gitlab
        operator: Exists
```

##### 2. 创建数据库

登录到数据库创建gitlab用户及数据库:

```
# 创建用户
CREATE USER 'gitlab'@'%' IDENTIFIED BY '******';

# 创建数据库并给gitlab用户授权:
CREATE DATABASE gitlabhq_production DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON gitlabhq_production.* TO gitlab@'%';
FLUSH PRIVILEGES;
```

#### 3.配置gitlab
> 重要：请认真阅读以下配置，修改参数后粘贴进`/etc/gitlab/gitlab.rb`文件中，若须其他配置请参考`gitlab/gitlab.rb`

```
# 设置url地址
external_url 'https://demo.gitlab.com.cn'
# 设置nginx转发https
nginx['listen_port'] = 80
nginx['listen_https'] = false
nginx['proxy_set_headers'] = {
  "X-Forwarded-Proto" => "https",
  "X-Forwarded-Ssl" => "on"
}
# 设置时区
gitlab_rails['time_zone'] = 'Asia/Shanghai'
# 设置用户可创建组
gitlab_rails['gitlab_default_can_create_group'] = true
# 设置用户可更改用户名
gitlab_rails['gitlab_username_changing_enabled'] = true
# 设置默认主题
gitlab_rails['gitlab_default_theme'] = 1
# 是否启用oauth2登陆
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['oauth2_generic']
# 设置默认登陆方式
gitlab_rails['omniauth_auto_sign_in_with_provider'] = 'oauth2_generic'
gitlab_rails['omniauth_block_auto_created_users'] = false
# 设置oauth2登陆详细参数
gitlab_rails['omniauth_providers'] = [
    {
      'name' => 'oauth2_generic',
      'app_id' => 'gitlab',
      'app_secret' => 'secret',
      'args' => {
        client_options: {
          'site' => 'http://api.gitlab.com.cn',
          'user_info_url' => '/oauth/api/user',
          'authorize_url'=> '/oauth/oauth/authorize',
          'token_url'=> '/oauth/oauth/token'
        },
        user_response_structure: {
          root_path: ['userAuthentication','principal'],
          id_path: ['userAuthentication','principal','userId'],
          attributes: {
              nickname: 'username',
              name: 'username',
              email: 'email'
          }
        },
        name: 'oauth2_generic',
        strategy_class: "OmniAuth::Strategies::ChoerodonOAuth2Generic",
        redirect_url: "https://demo.gitlab.com.cn/users/auth/oauth2_generic/callback"
      }
    }
  ]
# 关闭自带postgresql
postgresql['enable'] = false
# 配置mysql
gitlab_rails['db_adapter'] = "mysql2"
gitlab_rails['db_encoding'] = "utf8mb4"
gitlab_rails['db_collation'] = "utf8mb4_unicode_ci"
gitlab_rails['db_database'] = "gitlabhq_production"
gitlab_rails['db_pool'] = 20
gitlab_rails['db_username'] = "db_username"
gitlab_rails['db_password'] = "db_password"
gitlab_rails['db_host'] = "db_host"
gitlab_rails['db_port'] = 3306
# 关闭自带redis
redis['enable'] = false
# 配置redis
gitlab_rails['redis_host'] = "prod-gitlab-redis"
gitlab_rails['redis_port'] = 6379
# 启用smtp
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.mxhichina.com"
gitlab_rails['smtp_port'] = 465
gitlab_rails['smtp_user_name'] = "system@gitlab.io"
gitlab_rails['smtp_password'] = "system@gitlab"
gitlab_rails['smtp_domain'] = "smtp.mxhichina.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['gitlab_email_from'] = "system@gitlab.io"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = true
# 关闭prometheus
prometheus['enable'] = false
node_exporter['enable'] = false
```

- 使配置生效

```
# 停止启动的服务
gitlab-ctl stop
# 生效配置
gitlab-ctl reconfigure
# 启动服务
gitlab-ctl start
```

#### 三、优化

如果在gitlab中需要使用`emoji`图标(比如在issue、comment、merge request区域),那么需要做以下配置:

首先，需要对数据库表编码和行类型进行转换,如果一开始创建表时就使用`utf8mb4`格式，会造成初始化时列的长度超出限制的错误(767/4)。所以先使用utf8初始化完成后，在用sql进行转换。

修改数据库参数

```
# Aliyun RDS通过界面控制台修改:
innodb_large_prefix = ON

# 自建Mysql执行以下sql
set global innodb_file_format = `BARRACUDA`;
set global innodb_large_prefix = `ON`;
```

执行下边sql,并复制返回结果执行，然后就会将表的行格式设置为动态类型:

```
SELECT
	CONCAT( 'ALTER TABLE `', TABLE_NAME, '` ROW_FORMAT=DYNAMIC;' ) AS 'Copy & run these SQL statements:' 
FROM
	INFORMATION_SCHEMA.TABLES 
WHERE
	TABLE_SCHEMA = "gitlabhq_production" 
	AND TABLE_TYPE = "BASE TABLE" 
	AND ROW_FORMAT != "Dynamic";
```

继续执行sql，并复制返回结果执行,把表的编码进行转换:

```
SELECT
	CONCAT( 'ALTER TABLE `', TABLE_NAME, '` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;' ) AS 'Copy & run these SQL statements:' 
FROM
	INFORMATION_SCHEMA.TABLES 
WHERE
	TABLE_SCHEMA = "gitlabhq_production" 
	AND TABLE_COLLATION != "utf8mb4_general_ci" 
	AND TABLE_TYPE = "BASE TABLE";
```

这样在gitlab里就可以使用`emoji`图标了。对于`postgresql`是可以直接使用`utf8mb4`编码的。而在`mysql5.7`中可以将`ROW_FORMAT = "Dynamic"`这一值设置为默认属性,因此可能不会遇到这个问题。
