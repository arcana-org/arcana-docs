# The Terminal

A host's **Terminal** tab opens a terminal on the host, or in one of its
running jails, in the page. What runs on it is the host's own
`login(1)`, as `getty(8)` would run it on a serial line: you type an
account's name and its password, and the host's PAM
(`/etc/pam.d/login`) decides. Arcana picks no user, knows no password
and runs no shell of its own; root logs in only as the host's own
policy lets it (`securetty`, PAM). In a jail it is the jail's own
login, so the jail's own accounts.

The console decides one thing alone: who may reach the login prompt.
The one exception is a host that lets console users be mapped to its
accounts ([Mapped logins](#mapped-logins)).

## Opening one

Pick the host or one of its running jails, and **Connect**. The status
line says how it goes: connecting, connected on `pts/N`, logged in as
whom, ended and why, refused, or the connection dropped, with
**Connect** to start again. **Disconnect**, or leaving the tab, hangs
the session up. The terminal takes the theme's colours, and follows
the size of its box: a new size is sent to the host, whose programs
are told by `SIGWINCH`.

The terminal itself is xterm.js, vendored in Arcana's tree and served
by the console with the page, never fetched from elsewhere.

## Who may

- A console user **signed in with a security key** or passkey. A
  session a password opened, and an API token, never get a terminal.
- Whose role on that host is **operator** or **admin**: the console's
  owners on every host, a tenant's users on their tenant's hosts. A
  viewer never.
- From the console's own page, judged by its Origin.

The terminal is bound to the session that opened it, and the session
and the role are judged again **every second**: sign out, or have
your role on the host taken away, and the terminal is hung up within
that second.

On the host the request is an `arcana-stream` `terminal` stream, held
to the console user by the host's NACM (RFC 8341). A host whose
`exec-default` is deny (Settings) gives terminals to its group admin
alone, unless a rule permits `arcana-stream:terminal`.

## Mapped logins

A host's admin can map a console user to an account of the host, or of
one of its jails. That user's terminal there then runs `login -f` of
the account: the host's `login(1)` logs them in without asking the
account's password, and the security key they signed in with is what
proves who they are. A console user with no mapping for the host or
jail picked gets login's prompt as before.

A mapping grants that account's full rights, `sudo` and `wheel`
included; the tab says so above the form.

### The host's file

The console's mappings only choose among what the host allows, and
the host says what it allows in a file of its own,
`/usr/local/etc/arcana/terminal-users` (the agent's
`--terminal-users`). Without the file mapped logins are off on that
host, and the tab says so; `--terminal-users none` turns them off as
well. Each line is

```
host|jail:<name>  <account>  [+root]  <console user>...
```

- **host** for the host's own accounts, **jail:**`<name>` for a jail's.
  A host line never applies to a jail, nor a jail line to the host.
- `<account>`: the account those console users may become, a name of
  `[a-z_][a-z0-9_-]{0,31}`.
- **+root**: needed for an account of uid 0, `root`, `toor` or any
  other name for it (in a jail, uid 0 as the jail's `getent` says).
  Without it such an account is refused. A word that begins with `+` is
  a flag, never a console user, and `+root` is the only flag.
- Then the console users, by their names on the console.

`#` begins a comment. For example:

```
# host1's own accounts
host       alice   alice
host       ops     bob carol
host       root    +root alice
jail:www   www     carol
```

The agent opens the file as `sshd(8)`'s `StrictModes` would, and
refuses it whole otherwise: the file is root's, of mode 0600 or
stricter, not a symbolic link, 64 KB at most; every directory from `/`
down to it is root's, writable by no one else, and not a link; no line
has more than 64 words, and none is malformed or has an unknown flag.
No job, system file, bundle or YANG node of Arcana's writes it: it is
the host admin's word, edited on the host.

### What the agent checks

`login -f` asks no password and never calls `pam_acct_mgmt(3)`: the
account stage of PAM is skipped. On the host the agent makes those
checks itself, before it starts login, and refuses the session when
one fails:

- the account exists, and is not locked (`*LOCKED*`);
- the account has not expired, and its password is not past its change
  time ("password expired");
- its shell is not `nologin(8)` or `false(1)`;
- `/var/run/nologin` (or the file the account's login class names, see
  `nologin(5)`) is absent, unless the class has `ignorenologin` or the
  account is uid 0, as `pam_nologin(8)` lets root in;
- the login class's times, hosts and ttys (`login.conf(5)`) let it in.

`login.access(5)` and `securetty` are not consulted on this path: the
terminal-users file stands for them.

The session counts only once `utmpx(5)` says that very account logged
in on its terminal; until then whatever is typed is held, never written
to the terminal. Another account, or none within 10 seconds, and the
session is hung up ("login(1) logged in X, not Y").

### In a jail

A jail's accounts are the jail's, so before login the agent runs the
jail's own `getent(1)` in it by `jexec(8)` (`--terminal-getent`, 5
seconds at most): the account must be there, not locked, of uid 0 only
with `+root`, and with a shell that logs in. Then `jexec` runs the
jail's `login -f`. The jail's utmpx is the jail's to write, so it is
not read: a jail's mapped login is **never confirmed**, and what is
typed waits only until login has written something.

That leaves one gap, by design: an account removed from the jail
between its `getent` and `login -f` gets the jail's login prompt
instead, which is output, so typing reaches it. The jail's own
password then decides, as it would for anyone at that prompt.

### Checked again

- **On the host**, every 2 seconds while a mapped session lasts, the
  agent walks the file's way again and reads the file again when it
  changed. A directory loosened, the file gone, a line that no longer
  allows the session, or an uid-0 account whose line lost `+root`, and
  the session is hung up ("the host's terminal-users no longer allows
  it").
- **At the console**, every second, with the session and the role: a
  mapping removed or changed hangs its terminal up ("the mapped login
  was removed or changed"), and a plain terminal is hung up when the
  password prompt is turned off.

### Who may map

The host's admins see **Mapped logins** under the terminal: the
mappings (sorted and filtered), **Remove**, and a form to **Map** a
console user to an account of the host or of one of its jails. Only a
host's admin may change them, and only from a session a security key
opened (403 otherwise: not a password's session, not an API token);
an operator may not. Each write sends the host's entity-tag as read
(`If-Match`: 428 without it, 412 when it is stale), so a tab left open
brings back nothing changed behind it. Mappings are kept by the
console user's id, so a user removed and another made with the same
name has none. Over RESTCONF a mapping is
`arcana-console:hosts/host=<id>/terminal-login=<jail>,<user>` (`.` for
the host), PUT and DELETE.

The same form has the host's **Password prompt** switch:

- **allowed** (the default): a mapped user may still tick **The
  password prompt instead** and type a name and password as anyone
  would; a user with no mapping gets the prompt.
- **never: mapped logins alone**: no prompt at all. A mapped user gets
  their mapping, and anyone else is refused.

Before **Connect** the tab says "You will be logged in as alice",
then the status line "logging in as", and "(confirmed by the host)"
once utmpx tells it.

### NACM

On the host a mapped login is its own `arcana-stream` command,
`terminal-as`, marked `nacm:default-deny-all`: NACM refuses it unless a
rule permits it. Group admin may do anything. The operator rule-list
the console keeps in sync carries a `terminal-as` rule (and the plain
`terminal` one) only on a host whose `exec-default` is permit, where
operators had terminals already; on a host whose `exec-default` is
deny, operators get neither, and an admin who wants them adds a rule by
hand in a rule-list of their own (the console remakes its own whole).
Only the console, the socket's group or root on the unix socket may
ask; the console user is the one the request carries, the very name
NACM judged.

### Accounts with no password

An account with an empty password is one any login lets in. The agent
looks for them at its start and every 10 minutes, and raises one
fault, **empty-password** (Major) on `accounts`: "N accounts log in
with no password; see the host's auth log". The fault gives a count
alone, since every alarm reader, mail and Telegram see it; the names
go to the host's `LOG_AUTH` log alone, when they change. Set a
password, lock the account, or remove it.

### What is recorded

- On the host, `syslog(3)`'s `LOG_AUTH` at `notice` for each open,
  confirmation, refusal and end: the console user, the account, the
  scope (`host` or `jail:<name>`), the terminal and the address.
- In the console's trail: **terminal-opened** names the account
  requested, once the host's login writes or tells the login;
  **terminal-confirmed** follows when utmpx tells it (Allow when it is
  the account, Block otherwise); **terminal-closed** says "alice
  requested, confirmed" or "not confirmed". A refusal of the host's is
  a **terminal-refused** with its reason. Each mapping added, changed
  or removed is a **terminal-mapping** row and the switch a
  **terminal-prompt** row, with who and when.

### An older agent

An agent from before mapped logins does not know `terminal-as`; the
tab then says "this host's agent cannot do mapped logins: update it",
and never falls back to the prompt in its place. Update the agents
before mapping anyone (agent 0.321.0, console 0.466.0).

### Why no signed ticket

The console user goes to the host as the request's own user, with no
ticket, signature or nonce beside it. A signature would add nothing:
whoever holds the console already holds every host as root, by signed
agent updates and the `authorized_keys` files it writes. What the
host keeps for itself is the say over which accounts may be had this
way, and by whom: its terminal-users file, which nothing of Arcana's
writes.

## On the host

The agent opens a pseudo-terminal (`posix_openpt(2)`), makes its other
end the controlling terminal of a session of its own (`setsid(2)`,
`TIOCSCTTY`), and runs `login -h <where you come from>` on it; in a
jail, `jexec(8)` runs the jail's own login. Each session has a thread
of its own, which reads the terminal only as fast as the page takes
it: a page that falls behind holds back its own terminal, never the
agent nor another host's.

For the host's own sessions, the account that logged in is read from
`utmpx(5)` and shown on the page; a jail's utmpx is the jail's, and is
not read, so nothing is guessed there.

The stream's end hangs the session up as the kernel would: `SIGHUP` to
the terminal's foreground and to login's process group, the terminal
closed, and 5 seconds later `SIGKILL` to whatever is left of login's
group.

Limits:

| Where | Limit |
|---|---|
| The agent | 8 sessions at once; a session nobody types in for 30 minutes is hung up (`--terminal-idle`) |
| The console | 4 terminals per user, 32 in all |

## In the audit trail

Every terminal is in the console's audit trail, chained by HMAC as its
other records are:

- **terminal-refused**: who, the host and jail, from where, when the
  console said no;
- **terminal-opened**: who, the host (name and id) and jail, from
  where, once the host's login runs;
- **terminal-closed**: the bytes typed and written, how long it lasted,
  the account that logged in when the host told it ("not told"
  otherwise), and why it ended;
- for mapped logins, **terminal-confirmed**, **terminal-mapping** and
  **terminal-prompt** besides ([What is recorded](#what-is-recorded)).

The host logs each open, login and end to `syslog(3)` too, with the
bytes each way.

<div class="freebsd">

**FreeBSD:** `pts(4)` pseudo-terminals from `posix_openpt(2)`;
`login(1)` and PAM (`pam.d(5)`, `/etc/pam.d/login`); `login -f`,
`login.conf(5)`'s classes and `nologin(5)` for a mapped login;
`jexec(8)` for a jail's login and `getent(1)` to prove a jail's
account; `utmpx(5)` for who logged in; `syslog(3)`'s `LOG_AUTH`.

</div>
