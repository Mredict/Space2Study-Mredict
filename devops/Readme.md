vagrant up

ansible-playbook -i ansible/inventories/local/hosts.ini ansible/site.yml --ask-vault-pass

For deploying the app (not for the first time) you need to enter this commands:

ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.10"
ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.11"
ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.12"

chmod 600 .vagrant/machines/database/virtualbox/private_key
chmod 600 .vagrant/machines/backend/virtualbox/private_key
chmod 600 .vagrant/machines/frontend/virtualbox/private_key
