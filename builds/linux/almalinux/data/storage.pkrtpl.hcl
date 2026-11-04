%{~ if (length(partitions) > 0) || (length(lvm) > 0) || swap ~}
# cloud-init storage v2
storage:
  version: 1
  config:
    - type: disk
      id: disk0
      match:
        name: ${device}
%{ if length(partitions) > 0 }
%{ for p in partitions }
    - type: partition
      id: ${p.name}
      device: disk0
      size: ${p.size}MiB
%{ if p.format.fstype != "" }
    - type: format
      id: ${p.name}-fs
      volume: ${p.name}
      fstype: ${p.format.fstype}
%{ if p.format.label != "" }
      label: ${p.format.label}
%{ endif }
%{ endif }
%{ if p.mount.path != "" }
    - type: mount
      device: ${p.name}-fs
      path: ${p.mount.path}
%{ if p.mount.options != "" }
      options: ${p.mount.options}
%{ endif }
%{ endif }
%{ endfor }
%{ endif }

%{ if swap }
    - type: partition
      id: swap-part
      device: disk0
      size: 0
    - type: format
      id: swap-fs
      volume: swap-part
      fstype: swap
    - type: mount
      device: swap-fs
      path: "none"
      options: "swap"
%{ endif }

%{ if length(lvm) > 0 }
    # LVM layout
%{ for vg in lvm }
    - type: lvm_volgroup
      id: ${vg.name}
      devices: [ disk0 ]
%{ for lp in vg.partitions }
    - type: lvm_partition
      id: ${lp.name}
      volgroup: ${vg.name}
      size: ${lp.size}MiB
%{ if lp.format.fstype != "" }
    - type: format
      id: ${lp.name}-fs
      volume: ${lp.name}
      fstype: ${lp.format.fstype}
%{ if lp.format.label != "" }
      label: ${lp.format.label}
%{ endif }
%{ endif }
%{ if lp.mount.path != "" }
    - type: mount
      device: ${lp.name}-fs
      path: ${lp.mount.path}
%{ if lp.mount.options != "" }
      options: ${lp.mount.options}
%{ endif }
%{ endif }
%{ endfor }
%{ endfor }
%{ endif }
%{~ endif ~}
