#!/bin/bash
# 实例化一个项目
# 需传入项目名称prjectname（$1）和端口偏移量port_offset（$2）
# 会从8000开始  即 8001 8003(http) 8004(https) 8005(ajp) 8006留置
# 8000+offset*6+TYPE
# 1:start 3:http 4:https 5:ajp

# root用户才可以执行
if [ $UID -ne 0 ]; then
    echo "Superuser privileges are required to run this script."
    echo "e.g. \"sudo $0\""
    exit 1
fi

if [[ ! ${CATALINA_HOME} ]]; then
    echo "Please set path--CATALINA_HOME."
    exit 1
fi

if [[ ! ${CATALINA_BASE_TAR} ]]; then
    echo "Please set path--HB_CATALINA_BASE_TAR."
fi

if [[ ! ${JAVA_HOME} ]]; then
    echo "Please set path--JAVA_HOME."
fi

projectName=$1
port=$2

if [[ ! $projectName ]]; then
  echo "for example:$0 [name] [port_offset]"
  exit 1
fi

if [[ ! $port ]]; then
  echo "for example:$0 [name] [port_offset]"
  exit 1
fi

baseHome=/home/${projectName}

# 检查用户名是否可用
if [ -e ${baseHome} ]
then
  echo "${baseHome} already existing."
  exit 1
fi

# 新增用户
useradd -mr -d ${baseHome} -s /sbin/nologin -c "Project ${projectName} Account" ${projectName}
chmod -R g+rw ${baseHome}

# 如果存在/data1/projects 则创建在 /data1/projects/name_home
if [ -e /data1 ]; then
    if [ ! -e /data1/projects ]; then
        mkdir /data1/projects
    fi
    mv ${baseHome} /data1/projects/${projectName}
    ln -s /data1/projects/${projectName} ${baseHome}
fi

# 新建tomcat实例
tar zxvf ${CATALINA_BASE_TAR} -C ${baseHome}
mv ${baseHome}/tomcat_home_template ${baseHome}/tomcat
cp tomcat-server-normal.xml ${baseHome}/tomcat/conf/server.xml

# 默认关闭ajp，并且修改http port为指定值
PORT1=$[8000+${port}*6+1]
PORT2=$[8000+${port}*6+3]
PORT3=$[8000+${port}*6+4]
PORT4=$[8000+${port}*6+5]

sed -i -e "s@PORT_START@${PORT1}@g" ${baseHome}/tomcat/conf/server.xml
sed -i -e "s@PORT_HTTPS@${PORT3}@g" ${baseHome}/tomcat/conf/server.xml
sed -i -e "s@PORT_HTTP@${PORT2}@g" ${baseHome}/tomcat/conf/server.xml
sed -i -e "s@PORT_AJP@${PORT4}@g" ${baseHome}/tomcat/conf/server.xml

# 让systemctl管理tomcat作为系统服务
function MakeTomcatScript(){
  # $1 用户 $2 home
  T_Base=$2/tomcat
  # s/要替换的字符串/新的字符串/g
  #  / 可以用其他字符代替 比如# @
  # https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html
  # +好像用得不是太利索 用\+代替, 抓取数据应该用\(\)  代替数据应该用\1
  # ""
  # "s/\(address=\).*/\1$1/"
  # "s/\(JAVA_HOME=\"\).*\"/\1/g"
  cp ${CATALINA_HOME}/bin/tomcat.service /etc/systemd/system/tomcat_$1.service

  sed -i -e "s@#{JAVA_HOME}@"${JAVA_HOME}"@g"\
 -e "s@#{CATALINA_BASE}@"${T_Base}"@g"\
 -e "s@#{CATALINA_HOME}@"${CATALINA_HOME}"@g"\
 -e "s@#{TOMCAT_USER}@"$1"@g"\
 -e "s@#{CWD}@"$2"@g"\
 /etc/systemd/system/tomcat_$1.service

 systemctl daemon-reload
}

MakeTomcatScript ${projectName} ${baseHome}

# 给予组管理权
echo "" > /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /bin/systemctl start tomcat_${projectName}" >> /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /bin/systemctl stop tomcat_${projectName}" >> /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /bin/systemctl enable tomcat_${projectName}" >> /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /bin/systemctl disable tomcat_${projectName}" >> /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /bin/systemctl restart tomcat_${projectName}" >> /etc/sudoers.d/${projectName}
echo "%${projectName} ALL= NOPASSWD: /usr/bin/cp ROOT.war ${projectName}/tomcat/webapps/ROOT.war" >> /etc/sudoers.d/${projectName}
chown -R ${projectName}:${projectName} ${baseHome}
chown -R ${projectName}:${projectName} /data1/projects/${projectName}

# ACL控制
setfacl -m group:${projectName}:rwx ${baseHome}

# 启动并设置自动启动tomcat实例
systemctl start tomcat_${projectName}
systemctl enable tomcat_${projectName}

chmod -R g+rw ${baseHome}/tomcat

echo "        Deploy Summary" > ${baseHome}/README
echo "" >> ${baseHome}/README
echo "  Project Name:$projectName" >> ${baseHome}/README
echo "  Project Home:$baseHome" >> ${baseHome}/README
echo "  Tomcat Home:$baseHome/tomcat" >> ${baseHome}/README
IP=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
echo "  Project URL:http://$IP:$port/" >> ${baseHome}/README
echo "" >> ${baseHome}/README
echo "sudo systemctl start tomcat_${projectName} ; to start instance" >> ${baseHome}/README
echo "sudo systemctl stop tomcat_${projectName} ; to stop instance" >> ${baseHome}/README

echo "init project successfully!!!"