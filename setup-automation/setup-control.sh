#!/bin/bash

systemctl stop systemd-tmpfiles-setup.service
systemctl disable systemd-tmpfiles-setup.service


echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
chmod 440 /etc/sudoers.d/rhel_sudoers
# sudo -u rhel mkdir -p /home/rhel/.ssh
# sudo -u rhel chmod 700 /home/rhel/.ssh
# sudo -u rhel ssh-keygen -t rsa -b 4096 -C "rhel@$(hostname)" -f /home/rhel/.ssh/id_rsa -N "" -q
# sudo -u rhel chmod 600 /home/rhel/.ssh/id_rsa*


# nmcli connection add type ethernet con-name enp2s0 ifname enp2s0 ipv4.addresses 192.168.1.10/24 ipv4.method manual connection.autoconnect yes
# nmcli connection up enp2s0
# echo "192.168.1.10 control.lab control" >> /etc/hosts


# ## set user name
# USER=rhel

# ## setup rhel user
# touch /etc/sudoers.d/rhel_sudoers
# echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
# cp -a /root/.ssh/* /home/$USER/.ssh/.
# chown -R rhel:rhel /home/$USER/.ssh

# ## ansible home
# mkdir /home/$USER/ansible
# ## ansible-files dir
# mkdir /home/$USER/ansible-files

# ## ansible.cfg
# echo "[defaults]" > /home/$USER/.ansible.cfg
# echo "inventory = /home/$USER/ansible-files/hosts" >> /home/$USER/.ansible.cfg
# echo "host_key_checking = False" >> /home/$USER/.ansible.cfg

# ## chown and chmod all files in rhel user home
# chown -R rhel:rhel /home/$USER/ansible
# chmod 777 /home/$USER/ansible
# #touch /home/rhel/ansible-files/hosts
# chown -R rhel:rhel /home/$USER/ansible-files

## install python3 libraries needed for the Cloud Report
dnf install -y python3-pip python3-libsemanage

ansible-galaxy collection install ansible.aws

# Create a playbook for the user to execute
cat <<EOF | tee /tmp/setup.yml
### Automation Controller setup 
###
---
- name: Deploy credentials and AAP resources
  hosts: localhost
  gather_facts: false
  become: true
  vars:
    aws_access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') | default('AWS_ACCESS_KEY_ID_NOT_FOUND', true) }}"
    aws_secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') | default('AWS_SECRET_ACCESS_KEY_NOT_FOUND', true) }}"
    aws_default_region: "{{ lookup('env', 'AWS_DEFAULT_REGION') | default('AWS_DEFAULT_REGION_NOT_FOUND', true) }}"

  tasks:
  
    # - name: Add SSH Controller credential to automation controller
    #   ansible.controller.credential:
    #     name: SSH Controller Credential
    #     description: Creds to be able to SSH the contoller_host
    #     organization: "Default"
    #     state: present
    #     credential_type: "Machine"
    #     controller_host: "https://localhost"
    #     controller_username: admin
    #     controller_password: ansible123!
    #     validate_certs: false
    #     inputs:
    #       username: rhel
    #       ssh_key_data: "{{ lookup('file','/home/rhel/.ssh/id_rsa') }}"
    #   register: controller_try
    #   retries: 10
    #   until: controller_try is not failed

    - name: Add AWS credential to automation controller
      ansible.controller.credential:
        name: AWS_Credential
        description: Amazon Web Services
        organization: "Default"
        state: present
        credential_type: "Amazon Web Services"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        inputs:
          username: "{{ aws_access_key }}"
          password: "{{ aws_secret_key }}"
      register: controller_try
      retries: 10
      until: controller_try is not failed

    - name: Add EE to the controller instance
      ansible.controller.execution_environment:
        name: "AWS Execution Environment"
        image: quay.io/acme_corp/aws_ee
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Add project
      ansible.controller.project:
        name: "AWS Demos Project"
        description: "This is from github.com/ansible-cloud"
        organization: "Default"
        state: present
        scm_type: git
        scm_url: https://github.com/ansible-tmm/awsoptimize25.git
        default_environment: "Default execution environment"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Delete native job template
      ansible.controller.job_template:
        name: "Demo Job Template"
        state: "absent"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Create job template
      ansible.controller.job_template:
        name: "{{ item.name }}"
        job_type: "run"
        organization: "Default"
        inventory: "Demo Inventory"
        project: "AWS Demos Project"
        playbook: "{{ item.playbook }}"
        credentials:
          - "AWS_Credential"
        state: "present"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        extra_vars:
          controller_host: "{{ ansible_host }}"
      with_items:
        - { playbook: 'playbooks/aws_resources.yml', name: 'Create AWS Resources' }
        - { playbook: 'playbooks/aws_instances.yml', name: 'Create AWS Instances' }

    # - name: Launch a job template
    #   ansible.controller.job_launch:
    #     job_template: "Create AWS Resources"
    #     controller_host: "https://localhost"
    #     controller_username: admin
    #     controller_password: ansible123!
    #     validate_certs: false
    #   register: job

    # - name: Wait for job to finish
    #   ansible.controller.job_wait:
    #     job_id: "{{ job.id }}"
    #     controller_host: "https://localhost"
    #     controller_username: admin
    #     controller_password: ansible123!    
    #     validate_certs: false

    # - name: Launch a job template
    #   ansible.controller.job_launch:
    #     job_template: "Create AWS Instances"
    #     controller_host: "https://localhost"
    #     controller_username: admin
    #     controller_password: ansible123!
    #     validate_certs: false
    #   register: job2

    # - name: Wait for job2 to finish
    #   ansible.controller.job_wait:
    #     job_id: "{{ job2.id }}"
    #     controller_host: "https://localhost"
    #     controller_username: admin
    #     controller_password: ansible123!   
    #     validate_certs: false

    - name: Add an AWS INVENTORY
      ansible.controller.inventory:
        name: "AWS Inventory"
        description: "Our AWS Inventory"
        organization: "Default"
        state: present
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Add an AWS InventorySource
      ansible.controller.inventory_source:
        name: "AWS Source"
        description: "Source for the AWS Inventory"
        inventory: "AWS Inventory"
        credential: "AWS_Credential"
        source: ec2
        overwrite: "True"
        update_on_launch: "True"
        organization: "Default"
        source_vars:
          private: "false"
          hostnames:
            - 'tag:Name'
          compose: 
            ansible_host: public_ip_address
        state: present
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Update a single inventory source
      ansible.controller.inventory_source_update:
        name: "AWS Source"
        inventory: "AWS Inventory"
        organization: "Default"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false

    - name: Add ansible-1 host
      ansible.controller.host:
        name: "ansible-1"
        inventory: "Demo Inventory"
        state: present
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        variables:
            note: in production these passwords would be encrypted in vault
            ansible_user: rhel
            ansible_password: ansible123!
            ansible_host: controller

EOF

cat <<EOF | tee /tmp/aws_resources.yml
---
- name: Create AWS resources
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Create ssh key pair
      amazon.aws.ec2_key:
        region: "{{ ec2_region | default('us-east-1') }}"
        name: "ansible-demo"
      register: create_key

    - name: Save private key
      ansible.builtin.copy:
        content: "{{ create_key.key.private_key }}"
        dest: "ansible-demo.pem"
        mode: '0400'
      when: create_key.changed

    - name: Add machine credential
      ansible.controller.credential:
        name: "RHEL on AWS - SSH KEY"
        description: "Machine Credential for AWS instances"
        organization: "{{ organization | default('Default') }}"
        credential_type: Machine
        inputs:
          username: ec2-user
          ssh_key_data: "{{ lookup('file', 'ansible-demo.pem') }}"
        controller_username: "{{ controller_username | default('admin') }}"
        controller_password: "{{ controller_password | default('ansible123!') }}"
#        controller_host: "{{ controller_host | default('https://host.containers.internal/') }}"
        controller_host: "{{ controller_host | default('https://localhost/') }}"
        validate_certs: false

    - name: Create AWS VPC {{ ec2_name_prefix }}-vpc
      amazon.aws.ec2_vpc_net:
        name: "{{ ec2_name_prefix | default('ansible-demo') }}"
        cidr_block:
          - "{{ ec2_subnet | default('192.168.0.0/24') }}"
        region: "{{ ec2_region | default('us-east-1') }}"
        tags:
          ansible-demo: "true"
          ansible: "is awesome"
      register: create_vpc
      until: create_vpc is not failed
      retries: 5

    - name: Create EC2 security group aws-demo-sg
      amazon.aws.ec2_security_group:
        name: "{{ ec2_name_prefix | default('ansible-demo') }}"
        region: "{{ ec2_region | default('us-east-1') }}"
        description: AWS demo SG for the demo
        vpc_id: "{{create_vpc.vpc.id}}"
        tags:
          Name: "{{ ec2_name_prefix | default('ansible-demo') }}"
          ansible: "is awesome"
        rules:
          - proto: tcp
            ports:
              - 22
            cidr_ip: 0.0.0.0/0
          - proto: tcp
            ports:
              - 80
            cidr_ip: 0.0.0.0/0
      register: create_sg
      until: create_sg is not failed
      retries: 5

    # This task is subdiving up the 192.168.0.0/24 and getting a smaller chunk, a /28
    - name: Create subnet for aws-demo-vpc
      amazon.aws.ec2_vpc_subnet:
        region: "{{ ec2_region | default('us-east-1') }}"
        vpc_id: "{{ create_vpc.vpc.id }}"
        cidr: "{{ ec2_cidr | default('192.168.0.0/28') }}"
        tags:
          Name: "{{ ec2_name_prefix | default('ansible-demo') }}"
          ansible: "is awesome"
      register: create_subnet
      until: create_subnet is not failed
      retries: 15

    - name: VPC internet gateway is present for {{ create_vpc.vpc.id }}
      amazon.aws.ec2_vpc_igw:
        region: "{{ ec2_region | default('us-east-1') }}"
        vpc_id: "{{ create_vpc.vpc.id }}"
        tags:
          Name: "{{ ec2_name_prefix | default('ansible-demo') }}"
          ansible: "is awesome"
      register: igw
      until: igw is not failed
      retries: 15

    - name: VPC public subnet route table is present for {{ create_vpc.vpc.id }}
      amazon.aws.ec2_vpc_route_table:
        region: "{{ ec2_region | default('us-east-1') }}"
        vpc_id: "{{ create_vpc.vpc.id }}"
        subnets:
          - "{{ create_subnet.subnet.id }}"
        routes:
          - dest: 0.0.0.0/0
            gateway_id: "{{ igw.gateway_id }}"
        tags:
          Name: "{{ ec2_name_prefix | default('ansible-demo') }}"
          ansible: "is awesome"
      register: routetable
      until: routetable is not failed
      retries: 5

EOF

cat <<EOF | tee /tmp/aws_instance.yml
---
- name: Create lab instances in AWS
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    # Using ec2_ami_facts allows us to find a particular ami instance id regardless of region
    # Look for owner 309956199498 to find official Red Hat AMIs
    - name: Find ami instance-id for RHEL
      amazon.aws.ec2_ami_info:
        region: "{{ ec2_region | default('us-east-1') }}"
        owners: 309956199498
        filters:
          name: "RHEL-8*HVM-*Hourly*"
          architecture: x86_64
      register: amis

    # The module ec2_ami_facts can return multiple ami instances for a given search
    # we will grab the latest instance (by date) that meets our criteria
    - name: Set AMI for RHEL
      ansible.builtin.set_fact:
        rhel_ami: >
          {{ amis.images | selectattr('name', 'defined') | sort(attribute='creation_date') | last }}

    - name: Retrieve VPC subnet id
      amazon.aws.ec2_vpc_subnet_info:
        region: "{{ ec2_region | default('us-east-1') }}"
        filters:
          "tag:Name": "{{ ec2_vpc_subnet_name | default('ansible-demo') }}"
      register: ec2_vpc_subnet_id

    - name: Debug ec2_vpc_subnet_name
      ansible.builtin.debug:
        msg: "{{ ec2_vpc_subnet_id }}"

    - name: Create EC2 instances for ansible node (control node)
      amazon.aws.ec2_instance:
        key_name: "{{ ec2_key_name | default('ansible-demo') }}"
        security_group: "{{ ec2_security_group | default('ansible-demo') }}"
        instance_type: "{{ ec2_instance_type | default('t2.micro') }}"
        image_id: "{{ rhel_ami.image_id }}"
        region: "{{ ec2_region | default('us-east-1') }}"
        exact_count: "{{ ec2_exact_count | default('2') }}"
        state: running
        filters:
          "tag:instruqt": "true"
          instance-state-name: running
        tags:
          ansible-demo: "true"
          instruqt: "true"
        network:
          assign_public_ip: true
        vpc_subnet_id: "{{ ec2_vpc_subnet_id.subnets[0].subnet_id }}"
        volumes:
          - device_name: /dev/sda1
            ebs:
              volume_type: "{{ ec2_volume_type | default('gp3') }}"
              volume_size: "{{ ec2_volume_size | default('40') }}"
              iops: "{{ ec2_iops | default('3000') }}"
              throughput: "{{ ec2_throughput | default('125') }}"
              delete_on_termination: "{{ delete_on_termination | default(True) }}"
      register: control_output

    - name: Grab instance ids to tag them all
      amazon.aws.ec2_instance_info:
        region: "{{ ec2_region | default('us-east-1') }}"
        filters:
          instance-state-name: running
          "tag:instruqt": "true"
      register: control_output

    - name: Ensure tags are present
      amazon.aws.ec2_tag:
        region: "{{ ec2_region | default('us-east-1') }}"
        resource: "{{ item.1.instance_id }}"
        state: present
        tags:
          Name: "rhel{{ item.0 + 1 }}"
          Index: "{{ item[0] }}"
          launch_time: "{{ item.1.launch_time }}"
      with_indexed_items:
        - "{{ control_output.instances }}"
      when: control_output.instances | length > 0

EOF


export ANSIBLE_LOCALHOST_WARNING=False
export ANSIBLE_INVENTORY_UNPARSED_WARNING=False

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml
