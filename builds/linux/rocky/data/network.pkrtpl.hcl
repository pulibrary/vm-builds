# DHCP if ip is null, else static
network:
  version: 2
  ethernets:
    ${device}:
%{ if ip == null }
      dhcp4: true
      dhcp6: false
%{ else }
      addresses: [${ip}/${netmask}]
      gateway4: ${gateway}
%{ endif }
%{ if dns != null && length(dns) > 0 }
      nameservers:
        addresses:
%{ for d in dns }
          - ${d}
%{ endfor }
%{ endif }
