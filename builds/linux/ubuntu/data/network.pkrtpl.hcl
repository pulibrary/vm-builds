    version: 2
    ethernets:
      ${device}:
%{ if ip != null ~}
        addresses:
          - ${ip}/${netmask}
        gateway4: ${gateway}
        nameservers:
          addresses:
%{ for d in dns ~}
            - ${d}
%{ endfor ~}
%{ else ~}
        dhcp4: true
%{ endif ~}
