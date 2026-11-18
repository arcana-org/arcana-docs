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
  otherwise), and why it ended.

The host logs each open, login and end to `syslog(3)` too, with the
bytes each way.

<div class="freebsd">

**FreeBSD:** `pts(4)` pseudo-terminals from `posix_openpt(2)`;
`login(1)` and PAM (`pam.d(5)`, `/etc/pam.d/login`); `jexec(8)` for a
jail's login; `utmpx(5)` for who logged in; `syslog(3)`.

</div>
