#linux-run.sh LINUX_USER_PASSWORD NGROK_AUTH_TOKEN LINUX_USERNAME LINUX_MACHINE_NAME
#!/bin/bash
# /home/runner/.ngrok2/ngrok.yml

sudo useradd -m $LINUX_USERNAME
sudo adduser $LINUX_USERNAME sudo
echo "$LINUX_USERNAME:$LINUX_USER_PASSWORD" | sudo chpasswd
sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd
sudo hostname $LINUX_MACHINE_NAME

if [[ -z "$NGROK_AUTH_TOKEN" ]]; then
  echo "Please set 'NGROK_AUTH_TOKEN'"
  exit 2
fi

if [[ -z "$LINUX_USER_PASSWORD" ]]; then
  echo "Please set 'LINUX_USER_PASSWORD' for user: $USER"
  exit 3
fi

echo "### Install ngrok ###"
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok

echo "### Update user: $USER password ###"
echo -e "$LINUX_USER_PASSWORD\n$LINUX_USER_PASSWORD" | sudo passwd "$USER"

echo "### Start ngrok proxy for 80 port ###"
# Start HTTP tunnel
rm -f .ngrok-http.log
ngrok http 80 --log=".ngrok-http.log" &
sleep 5
HTTP_URL=$(grep -o -E "https?://[^ ]+" .ngrok-http.log)
echo "HTTP URL: $HTTP_URL"rm -f .ngrok-ssh.log
ngrok tcp 22 --log=".ngrok-ssh.log" &
sleep 5
SSH_CMD=$(grep -o -E "tcp://[^ ]+" .ngrok-ssh.log | sed "s/tcp:\/\//ssh $USER@/" | sed "s/:/ -p /")
echo "SSH Command: $SSH_CMD"

rm -f .ngrok-ssh.log
ngrok tcp 22 --log=".ngrok-ssh.log" &
sleep 5
SSH_CMD=$(grep -o -E "tcp://[^ ]+" .ngrok-ssh.log | sed "s/tcp:\/\//ssh $USER@/" | sed "s/:/ -p /")
echo "SSH Command: $SSH_CMD"

sleep 10
if [[ -z "$HAS_ERRORS" ]]; then
  echo ""
  echo "=========================================="
  echo "To connect: $(grep -o -E "tcp://(.+)" < .ngrok.log | sed "s/tcp:\/\//ssh $USER@/" | sed "s/:/ -p /")"
  echo "or conenct with $(grep -o -E "tcp://(.+)" < .ngrok.log | sed "s/tcp:\/\//ssh (Your Linux Username)@/" | sed "s/:/ -p /")"
  echo "=========================================="
else
  echo "$HAS_ERRORS"
  exit 4
fi
