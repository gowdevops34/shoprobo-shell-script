CHECK_ROOT() {
  USER_ID=$(id -u)
  if [ $USER_ID -ne 0 ]; then
    echo -e "\e[31mYou should run this script as root user or sudo this script\e[0m"
    exit 1
  fi
}

CHECK_STAT() {
echo "---------$1----------" >>${LOG}
if [ $1 -ne 0 ]; then
  echo -e "\e[31mFAILED\e[0m"
  echo -e "\n Check log file - ${LOG} for errors\n"
  exit 2
else
  echo -e "\e[32mSUCCESS\e[0m"
fi
}

LOG=/tmp/roboshop.log
rm -f $LOG

PRINT() {
  echo "---------$1----------" >>${LOG}
  echo "$1"
}

APP_COMMON_SETUP() {
    PRINT "Creating Application User"
    id roboshop &>>${LOG}
    if [ $? -ne 0 ]; then
      useradd roboshop &>>${LOG}
    fi
    CHECK_STAT $?

    PRINT "Downloading ${COMPONENT} Content"
    curl -s -L -o /tmp/${COMPONENT}.zip "https://github.com/roboshop-devops-project/${COMPONENT}/archive/main.zip" &>>${LOG}
    CHECK_STAT $?

    cd /home/roboshop

    PRINT "Remove old Content"
    rm -rf ${COMPONENT} &>>${LOG}
    CHECK_STAT $?

    PRINT "Extract ${COMPONENT} Content"
    unzip /tmp/${COMPONENT}.zip &>>${LOG}
    CHECK_STAT $?
}

SYSTEMD() {
    PRINT "Update SystemD Configuration"
    sed -i -e 's/REDIS_ENDPOINT/redis.roboshop.internal/' -e 's/CATALOGUE_ENDPOINT/catalogue.roboshop.internal/' -e 's/MONGO_ENDPOINT/mongodb.roboshop.internal/' -e 's/MONGO_DNSNAME/mongodb.roboshop.internal/' -e 's/CART_ENDPOINT/cart.roboshop.internal/' -e 's/DBHOST/mysql.roboshop.internal/' -e 's/CARTHOST/cart.roboshop.internal/' -e 's/USERHOST/user.roboshop.internal/' -e 's/AMQPHOST/rabbitmq.roboshop.internal/' /home/roboshop/${COMPONENT}/systemd.service &>>${LOG}
    CHECK_STAT $?

    PRINT "setup systemD Configuration"
    mv /home/roboshop/${COMPONENT}/systemd.service /etc/systemd/system/${COMPONENT}.service &>>${LOG} && systemctl daemon-reload
    CHECK_STAT $?

    PRINT "Start ${COMPONENT} Service"
    systemctl enable ${COMPONENT} &>>${LOG} && systemctl restart ${COMPONENT} &>>${LOG}
    CHECK_STAT $?
}

NODEJS() {

  CHECK_ROOT

  PRINT "Setting Up Nodejs YUM Repo is "
  curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash &>>${LOG}
  CHECK_STAT $?

  PRINT "Installing Nodejs"
  yum install nodejs -y &>>${LOG}
  CHECK_STAT $?

  APP_COMMON_SETUP

  PRINT "Install Nodejs Dependencies for ${COMPONENT} Component"
  mv ${COMPONENT}-main ${COMPONENT} && cd ${COMPONENT} && npm install &>>${LOG}
  CHECK_STAT $?

  SYSTEMD
}

NGINX() {
  CHECK_ROOT
  PRINT "Installing Nginx"
  yum install nginx -y &>>${LOG}
  CHECK_STAT $?

  PRINT "Download ${COMPONENT} content"
  curl -s -L -o /tmp/${COMPONENT}.zip "https://github.com/roboshop-devops-project/${COMPONENT}/archive/main.zip" &>>${LOG}
  CHECK_STAT $?

  PRINT "Clean Old Content"
  cd /usr/share/nginx/html
  rm -rf * &>>${LOG}
  CHECK_STAT $?

  PRINT "Extract ${COMPONENT} Content"
  unzip /tmp/${COMPONENT}.zip &>>${LOG}
  CHECK_STAT $?

  PRINT "Organise ${COMPONENT} Content"
  mv ${COMPONENT}-main/* . && mv static/* . && rm -rf ${COMPONENT}-main README.md && mv localhost.conf /etc/nginx/default.d/roboshop.conf
  CHECK_STAT $?

  PRINT "Update ${COMPONENT} Configuration"
  sed -i -e '/catalogue/ s/localhost/catalogue.roboshop.internal/' -e '/user/ s/localhost/user.roboshop.internal/' -e '/cart/ s/localhost/cart.roboshop.internal/' -e '/payment/ s/localhost/payment.roboshop.internal/' -e '/shipping/ s/localhost/shipping.roboshop.internal/' /etc/nginx/default.d/roboshop.conf
  CHECK_STAT $?
  # or using for loop
  # for backend in catalogue cart user shipping payment ; do
  # PRINT "Update Configuration for - $backend"
  # sed -i -e "/$backend/ s/localhost/$backend.roboshop.internal/" /etc/nginx/default.d/roboshop.conf
  # CHECK_STAT $?
  # done

  PRINT "Start Nginx Service"
  systemctl enable nginx &>>${LOG} && systemctl restart nginx &>>${LOG}
  CHECK_STAT $?
}

MAVEN() {
 CHECK_ROOT

 PRINT "Installing Maven"
 yum install maven -y &>>${LOG}
 CHECK_STAT $?

 APP_COMMON_SETUP

 PRINT "Compile ${COMPONENT} Code"
 mv ${COMPONENT}-main ${COMPONENT} && cd ${COMPONENT} && mvn clean package &>>${LOG} && mv target/${COMPONENT}-1.0.jar ${COMPONENT}.jar
 CHECK_STAT $?

 SYSTEMD

}

PYTHON() {
  CHECK_ROOT

  PRINT "INSTALL PYTHON"
  yum install python36 gcc python3-devel -y &>>${LOG}
  CHECK_STAT $?

  APP_COMMON_SETUP

  PRINT "Install ${COMPONENT} Dependencies"
  mv ${COMPONENT}-main ${COMPONENT} && cd /home/roboshop/${COMPONENT} && pip3 install -r requirements.txt &>>${LOG}
  CHECK_STAT $?

  PRINT "Update ${COMPONENT} Configuration"
  sed -i -e "/^uid/ c uid = $(id -u roboshop)" -e "/^gid/ c gid = $(id -g roboshop)" /home/roboshop/${COMPONENT}/${COMPONENT}.ini
  CHECK_STAT $?

  SYSTEMD
}