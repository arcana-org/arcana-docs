# Packages and jobs

## Packages

Of the host or a running jail. **Installed**, at first, lists what is
installed, from the host's own database without asking the repository:
each package's version, whether it was asked for by hand or came
automatically as what another needs, its size, its port and what it is.

![Installed packages](../img/tour-packages.png)

- **Upgrades** asks the repository what is newer, with **Check** (`pkg
  update` first), a dry run, and **Upgrade** of the selected packages
  or of all.
- **Network** says how `pkg` reaches the repository: IPv4 or IPv6
  (either), IPv4 only (`pkg -4`) or IPv6 only (`pkg -6`); pressed, a box
  changes it. Every box that has `pkg` contact the repository (Install…,
  an upgrade, a base conversion) asks it again, the last choice
  already picked and kept in the browser for the next time.
- **From**, beside Upgrade and in Install…, takes the packages from one
  of the repositories `pkg` is configured with there alone (`pkg
  upgrade -r`, `pkg install -r`), enabled or not, such as a Builder's
  poudriere repository with a debug build of BIRD; **any repository**
  leaves it to `pkg`'s own configuration
  ([pkg.conf(5)](https://man.freebsd.org/pkg.conf/5)). The agent
  refuses a name that is not one of them.
- **Clean…** empties `pkg`'s cache of downloaded packages; what is
  installed stays. One box asks what: what is no longer needed,
  packages no installed version needs or that the repository no longer
  has (`pkg clean`), or every downloaded package (`pkg clean -a`), which
  upgrades then download again. On the host's page it asks where too:
  the host, its running jails, or both; the jails are a job each in one
  batch, so a jail without `pkg`, or whose `pkg` refuses, fails alone.
  On a jail's page it is that jail's.

  ![Clean the package cache: what, and where](../img/pkg-clean.png)
- **Upgrade the jails**, on the host's page, upgrades every running
  jail's packages at once (`pkg upgrade -y` in each), a job each in one
  batch, after asking: a jail without `pkg`, or whose repositories
  cannot be read, fails alone. The host's own packages are not touched.
  The agent runs four of these jobs at once, each in a jail of its own,
  a jail's own one after another, so a download that stalls in one jail
  holds up no other; the next job of another kind waits for them.
  A `pkg` that says nothing for ten minutes (`--pkg-idle`) is stopped
  with what it started in the jail, and its job fails saying so; one
  at work can also be cancelled from **Recent tasks**.
- **Install…** installs packages by name, on the host or in the jail
  picked (`pkg install -y`).

### A jail's base system by pkg

A running jail of FreeBSD 15.1 or later whose base system is still the
release's files has **To pkgbase…** on its packages: the base system
packages installed over its files, from the FreeBSD-base repository of
its own release (or a newer branch, `16` for the latest of that major),
the sets named (`FreeBSD-set-base-jail` when none;
`FreeBSD-set-minimal-jail` is smaller). A jail already on pkgbase has
**Base upgrade…** instead: to the release named, `16` or `15.2`, its
base packages first, then its other packages for the new ABI, never
beyond the host's kernel.

- **Base repository**: by default FreeBSD's official repository,
  written into the jail under Arcana's own name, **arcana-base**
  (`/usr/local/etc/pkg/repos/arcana-base.conf`), so that a mirror of
  yours named like FreeBSD's is not merged into it. Once the job is
  through the file is taken out again, since the base installed has
  its own `FreeBSD-base`; a job that failed keeps it. Or
  one of the jail's own repositories, as it is: it must have the
  release.
- Both keep the jail's `/etc` aside in `/var/backups` first, put back
  the jail's own files `pkg` set aside (its users and groups merged
  with the new base's accounts), and name in the trace the packages'
  versions left beside them as `.pkgnew`, to merge by hand. Restart
  the jail after.

`pkg` sets flags on the base system's files (`chflags(2)`, such as
`schg`), which a jail may do only with `allow.chflags`. Where the jail
may not, the agent refuses a conversion or a base upgrade before
anything changes (an upgrade or install of packages fails where `pkg`
meets the flag, and says why), and the page asks: **Allow now and retry** sets `allow.chflags` on the running
jail alone, not in its file, so it is gone at the jail's next start,
and not in safe mode, then sends the same job again. The question
comes for a conversion, a base upgrade, and an upgrade or install of
packages in a jail on pkgbase.

### Newer than the host

When `pkg` refuses packages built for a newer FreeBSD than the host's
(OSVERSION), the console asks whether to go on anyway, and approved,
does it again with `IGNORE_OSVERSION=yes`.

From a shell: `arcanactl packages [-i] [-r] [-4 | -6] [jail]` (with the
repositories), `pkg-upgrade [-O] [-r repo] …`, `pkg-clean [-a] [-j jail | -J]`, `pkg-install [-O] [-4 | -6] [-r repo]
[-j jail] package …`, `jail-base jail convert [-r repo] [-b release] [set …]`,
`jail-base jail upgrade [-r repo] release`.

## Jobs

The host's own record of what it was asked to change, by this console
or with `arcanactl -q`: the last 64, forgotten when the agent restarts.
A row opens its trace. Above the list it says what the agent is doing
now that is not a job, a request somebody waits for such as a check of
the packages, since when, and whether the agent was told to stop and
waits for it.

![A host's jobs](../img/tour-jobs.png)

<div class="freebsd">

**FreeBSD:** `pkg(8)`, for a jail with `pkg -j`, its repositories
`pkg.conf(5)`; pkgbase's `FreeBSD-set-*` packages; `jail(8)`'s
`allow.chflags` and `chflags(2)`. A job is the agent's own, run by a
thread of it and kept in its memory.

</div>
