#!/bin/bash
# 初始化centos服务器

#必须是root用户才可以执行
if [ $UID -ne 0 ]; then
    echo "Superuser privileges are required to run this script."
    echo "e.g. \"sudo $0\""
    exit 1
fi

#设置一下主机名
echo -n "please set the host name"
read hostname

if [[ ! $hostname ]]; then
  echo "$0 hostname is required"
  exit 1
fi

hostnamectl --static --transient --pretty set-hostname $hostname

# 安装一些必要的软件并启动相关服务
yum -y install net-tools ntp redis memcached httpd lvm2 firewalld wget device-mapper java-1.8.0-openjdk
systemctl enable ntpd
systemctl enable redis
systemctl enable memcached
systemctl enable httpd
systemctl enable firewalld
systemctl start firewalld

# 将http端口开放
firewall-cmd --add-service=http --permanent

# 安装tomcat，清华大学源，据说速度很快
echo "starting to install tomcat8"
GZTomcat=`ls ../configuration/tomcat/apache-tomcat*`

tar -C /usr -xzf $GZTomcat

catalinaHome=`ls /usr/apache-tomcat* -d`

# tomcat空实例
cp ../configuration/tomcat/tomcat_base.tar.gz ${catalinaHome}/
#  systemctl管理需要用到的tomcat.service
cp ../configuration/tomcat/tomcat.service ${catalinaHome}/bin/

chown -R root:root ${catalinaHome}
chmod +x ${catalinaHome}/bin/*.sh

# 设置环境变量
echo "export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk" >> /etc/environment
echo "export CATALINA_HOME=${catalinaHome}" >> /etc/environment
echo "export CATALINA_BASE_TAR=${catalinaHome}/tomcat_base.tar.gz" >> /etc/environment

# jdbc
cp ../configuration/jdbc/*.jar ${catalinaHome}/lib

# httpd
cp ../configuration/httpd/*.so /etc/httpd/modules/
cp ../configuration/httpd/*.conf /etc/httpd/conf.modules.d/
cp ../configuration/httpd/*.properties /etc/httpd/conf/
service httpd configtest

# 添加自己并加入root权限
useradd allan
usermod -aG wheel allan
echo "efs123456" |passwd --stdin allan
chage -d0 allan

echo "init server successfully!!!"


