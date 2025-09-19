%{~ if (ip != null) || (gateway != null) || (dns != null && length(dns) > 0) ~}
network:
  version: 2
  ethernets:
    ${device}:
%{ if ip != null }
      addresses: [${ip}/${netmask}]
%{ endif }
%{ if gateway != null }
      gateway4: ${gateway}
%{ endif }
%{ if dns != null && length(dns) > 0 }
      nameservers:
        addresses:
%{ for d in dns }
          - ${d}
%{ endfor }
%{ endif }
%{~ endif ~}

