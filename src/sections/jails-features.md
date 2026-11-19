# Jails and Arcana's features

A FreeBSD host often runs its services in jails rather than on itself,
so Arcana keeps one rule: **every feature that serves a service works
for that service in a jail too**. Pick the jail where the host is
picked (a picker at the left of the tab's toolbar, **Where** or **Runs
in**), or give `arcanactl` the jail with `-j`.

Nothing is installed in the jail for Arcana: there is no agent in it.
The host's agent does the work from outside, in one of three ways:

- it **runs the jail's own program** in the jail, by `jexec(8)`:
  `service(8)`, `sysrc(8)`, `birdc(8)`, `wg(8)`, `ipfw(8)`, Suricata,
  SSLproxy, so that what parses a configuration is the version that runs
  it;
- it **reads and writes the jail's files beneath the jail's root**, by
  descriptors opened from the root (`O_RESOLVE_BENEATH`, `O_NOFOLLOW`):
  a link the jail put in the way refuses the write, and nothing is ever
  written outside the jail;
- it **attaches a helper to the jail** (`jail_attach(2)`) where it must
  see what the jail sees: its scripts, its processes, its network.

A plugin a feature needs is looked for in the jail and installed there
only when you press **Install** (`pkg -j <jail> install ...`).

## What works in a jail

*Any* means any running jail, with the host's network or one of its
own. *vnet* means a jail with its own network stack (`vnet = new` in
its `jail.conf`).

| Feature | Jails | vnet needed | Notes |
|---|---|---|---|
| [Services](host.md#services-of-a-running-jail) | any | no | the jail's `service -j` and `sysrc -j`; [Mend pidfile](host.md#a-stale-pidfile) beneath the jail's root |
| [Packages](packages-jobs.md) | any | no | `pkg -j`; **Upgrade the jails** does every running one |
| [Processes](kernel.md#processes) | any | no | listed by jail; a signal or nice names the jail in its job |
| [Crash cores](kernel.md#crash-cores) | any | no | found beneath the jail's root; backtrace with the jail's own program and libraries |
| [The Terminal](terminal.md) | any | no | the jail's own login and accounts |
| [Log](log.md#log) | any | no | the jail's `/var/log` |
| [syslog, newsyslog, periodic, krb5, dma](system.md#a-jails-own-files) | any | no | the jail's own files; its daemon told by its `service(8)` |
| [syslog as YANG](system.md#a-jails-syslog-as-yang) | any | no | `arcana-syslog`'s `jail-syslog`, the jail's root an RFC 8528 mount point |
| [SSH](ssh.md) | any | no | the jail's own `sshd` |
| [Certificates](certificates.md) | any | no | the jail's own `certctl` |
| [Mail: OpenSMTPD](mail.md) | any | no | |
| [FEC relay](relay.md) | any | no | safe mode undone in the jail; rates named `<jail>:<tag>` |
| [URL filter, antivirus](security.md#in-a-jail) | any | no | Squid, c-icap and ClamAV the jail's own; freshclam started in the jail |
| [IDS/IPS](security.md#in-a-jail) | any | to prevent | detection where the jail's devfs shows `bpf(4)`; prevention diverts in the jail's ipfw, set 25 rule 6 |
| [SSL inspection](security.md#ssl-inspection-in-a-jail) | any | no | a vnet jail's `fwd` rules in its own ipfw; another's in the host's set 27, sent to the jail's address |
| [Datasets](storage.md#datasets) | any | no | given with `zfs jail`; the jail's own `zfs` lists them |
| [Utilization](utilization.md) | any | no | each jail's share of the CPUs and its memory |
| [Network](network.md#a-jails-own-network) | vnet | yes | interfaces, routes, netgraph, bridges, Geneve, CARP, capture, monitors, path checks |
| [Firewall](firewall.md#a-jails-firewall) | vnet | yes | the jail's own ipfw and its rules |
| [Sysctl](kernel.md#sysctl) | vnet | yes | the jail's `net.*` values alone, `arcanactl -j <jail> sysctl` |
| [WireGuard, BIRD, strongSwan](plugins.md#in-a-jail) | vnet | yes | each the jail's own program |
| [IPsec: ipsec.conf, manual SAs](network.md#ipsec) | vnet | yes | SAs by PF_KEY in the jail's stack; keys kept on the host as `<interface>@<jail>` |
| [Router advertisements](network.md#interfaces) | vnet | yes | the jail's `rtadvd.conf` and `rtadvd` |
| [NFS server](storage-services.md#in-a-vnet-jail) | vnet | yes | also `allow.nfsd`, `enforce_statfs` 1 or 2, a root that is a mount point; TCP only, no pNFS, no `sharenfs` |
| [Events](log.md#events) | vnet | yes | the jail's network watched as the host's |
| [SD-WAN edge](../sdwan/document.md) | vnet | yes | BIRD, dnsmasq, unbound, Squid, Suricata and SSLproxy run in the jail; not NTP, rtadvd or manual SAs yet |

## What stays the host's

Some things belong to the kernel or to the boot, which every jail
shares with the host. Arcana refuses them for a jail and says why:

| Feature | Why it is the host's |
|---|---|
| `loader.conf`, kernel modules | one kernel, loaded at the host's boot; a jail cannot load modules |
| `devd(8)` | a jail has no devices' events |
| `rctl(8)` | its rules are the host's kernel's: a jail is limited from the host (subject `jail`) |
| audit | `audit(4)` records the jails' processes with the host's |
| `devfs.rules` | a jail's `/dev` is the rule set its `jail.conf` names (`devfs_ruleset`) |
| securelevel at boot | a jail's securelevel is its `jail.conf`'s `securelevel` |
| NTP | one clock; a jail may not set it |
| [Storage](storage.md): pools, GEOM, disks, mounts, swap | the host's devices; `geom`, `zfs`, `zpool`, `gpart`, `cam`, `mount`, `umount`, `swapon`, `swapoff` refuse `-j` |
| [iSCSI target](storage-services.md#iscsi) | ctld serves the kernel's CAM Target Layer (`ctl(4)`), which no jail has |
| [HAST](storage-services.md#hast) | hastd replicates GEOM providers and makes `/dev/hast/*`, which no jail has |

A *service jail* that `rc(8)` makes for one of the host's services
(`NAME_svcj`) has the host's root, so its services are the host's own
and are not listed apart. See [Service jails](system.md#system).

## arcanactl -j

`arcanactl -j <jail>` works in a running jail instead of the host.
The `-j` entry of [arcanactl(8)](../reference/arcanactl.md) lists the
commands that take it, and each command's own entry says what `-j`
does there:

- on the network of a vnet jail: `net`, `route`, `interface`, `ng`,
  `wg`, `bird`, `ipfw`, `bridge`, `geneve`, `ipsec`, `neigh`, `carp`,
  `capture`, `path-check`, `monitor`, `rtadvd`, `nfs` and `sysctl` (its
  `net.*` values), and `ipsec-sa`;
- on any jail's own daemons and files: `services`, `service`, `sshd`,
  `cert`, `smtpd`, `speeder`, `ps`, `signal`, `renice`, `log`,
  `storage` (what the jail's own `zfs` sees), `system`, `sysfile`,
  `crashes backtrace`, `clamav`, `sslproxy`, and `get` and `edit` of
  `syslog`;
- `pkg`'s commands take a `-j` of their own.

With `-p`, a change is kept in the jail's own `rc.conf`. The commands
of what stays the host's refuse `-j` with the reason, rather than
quietly working on the host.

<div class="freebsd">

**FreeBSD:** `jail(8)` and `jail.conf(5)`; `libjail(3)` to read a
running jail's parameters; `jexec(8)` and `jail_attach(2)` to work in
it; `service(8)` and `sysrc(8)`, both with `-j`; `pkg(8)`'s `-j`;
`vnet(9)`, the network stack a jail may have of its own, with its own
routing tables, ipfw, IPsec databases and divert sockets.

</div>
