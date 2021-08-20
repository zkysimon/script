#!/bin/sh

apt-get install curl -y
mkdir /root/.ssh
cd /root/.ssh
curl -o authorized_keys https://cdn.jsdelivr.net/gh/zkysimon/script@latest/pubkey/id_rsa.pub
chmod 600 authorized_keys
chmod 700 ~/.ssh
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd
