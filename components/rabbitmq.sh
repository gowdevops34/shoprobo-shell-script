source components/common.sh

CHECK_ROOT

if [ -z "$RABBITMQ_USER_PASSWORD" ]; then
  echo "Export RABBITMQ_USER_PASSWORD env variable"
  exit 1
fi

PRINT "Setup Yum Repos of Erlang"
curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | sudo bash &>>${LOG}
CHECK_STAT $?

PRINT "Install Erlang"
yum install erlang -y &>>${LOG}
CHECK_STAT $?

PRINT "Setup Yum Repos of Rabbitmq"
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | sudo bash &>>${LOG}
CHECK_STAT $?

PRINT "Install Rabbitmq"
yum install rabbitmq-server -y &>>${LOG}
CHECK_STAT $?

PRINT "Start Rabbitmq Service"
systemctl enable rabbitmq-server &>>${LOG} && systemctl start rabbitmq-server &>>${LOG}
CHECK_STAT $?

rabbitmqctl list_users | grep roboshop &>>${LOG}
if [ $? -ne 0 ]; then
  PRINT "Create Rabbitmq User"
  rabbitmqctl add_user roboshop ${RABBITMQ_USER_PASSWORD} &>>${LOG}
fi

PRINT "Rabbitmq User Tags and Permissions"
rabbitmqctl set_user_tags roboshop administrator &>>${LOG} && rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>${LOG}
CHECK_STAT $?