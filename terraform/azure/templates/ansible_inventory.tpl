# Auto-generated Ansible Inventory by Terraform
# Generated at: ${timestamp()}
# Domain: ${domain_name}

all:
  vars:
    ansible_user: ${ansible_user}
    ansible_password: ${ansible_password}
    ansible_connection: winrm
    ansible_winrm_transport: ntlm
    ansible_winrm_server_cert_validation: ignore
    ansible_port: 5985
    domain_name: ${domain_name}
    domain_netbios: ${domain_netbios}
    domain_admin_user: ${domain_netbios}\${ansible_user}
    domain_admin_password: ${ansible_password}
    dc1_ip: ${dc1_ip}
    dc2_ip: ${dc2_ip}
    dns_forwarders: [8.8.8.8, 1.1.1.1]
    dns_import_dir: 'C:\dns-import'

  children:
    windows:
      hosts:
        dc1:
          ansible_host: ${dc1_public_ip}
          private_ip: ${dc1_ip}
          role: domain_controller
          dc_number: 1

        dc2:
          ansible_host: ${dc2_public_ip}
          private_ip: ${dc2_ip}
          role: domain_controller
          dc_number: 2

    domain_controllers:
      hosts:
        dc1:
        dc2:

    windows_clients:
      hosts:
%{ for client in clients ~}
        ${client.name}:
          ansible_host: ${client.public_ip}
          private_ip: ${client.private_ip}
          role: domain_client
%{ endfor ~}
