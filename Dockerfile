FROM alpine:latest
LABEL maintainer="Luis Acosta <luis13cst@gmail.com>"

# Install Ansible and dependencies
RUN apk update && apk add ansible openssh nano

# Copy hosts and config file
COPY disk/etc/ansible /etc/ansible
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg

# Copy playbooks
RUN mkdir -p /playbook
COPY disk/playbook /playbook
