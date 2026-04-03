# SFTP Chroot Jail Setup

> Secure file transfer with a jailed user on RHEL/CentOS/Oracle Linux  
> Protocol: SFTP over SSH · User: `john` · Group: `sftponly`

---

## How It Works

SFTP (SSH File Transfer Protocol) runs on top of SSH and adds encrypted file transfer capabilities. The chroot jail locks the user inside their home directory — they cannot navigate outside of it, and SSH login is disabled entirely.

```
Client (sftp john@host)
        │
        ▼  SSH (port 22) + encrypted session
   sshd daemon
        │
        ▼  ForceCommand internal-sftp
   Chroot jail → /home/john/
        │
        └── datadir/    ← only writable space for john
```

### Why root must own the jail directory

`sshd` enforces a strict security rule: the chroot root directory **must be owned by root** and must **not** be writable by the jailed user. If john owned `/home/john`, he could potentially escape the jail. The writable subdirectory `datadir/` is his actual working space.

```
/home/john/        ← owned by root  (chmod 755) — chroot anchor
└── datadir/       ← owned by john  (chmod 755) — john's writable space
```

---

## Prerequisites

- RHEL / CentOS / Oracle Linux
- `openssh-server` package
- SELinux active (handled below)

---

## Setup

### 1. Install & start OpenSSH

```bash
dnf install openssh-server -y

# Verify
ssh -V

systemctl enable sshd.service
systemctl start sshd.service
```

### 2. Check SSH is listening on port 22

```bash
ss -tulpn | grep :22
```

> `netstat` is not available on Oracle Linux — use `ss` with a space before the port.

### 3. Create the group and user

```bash
groupadd sftponly

# -g: assign group, -s /bin/false: disable shell login
useradd john -g sftponly -s /bin/false

passwd john
```

### 4. Configure the chroot directory

```bash
# Create john's writable subdirectory
mkdir /home/john/datadir

# Root must own the jail root (sshd requirement)
chown root /home/john
chmod 755 /home/john

# John owns his working directory
chown john /home/john/datadir
chmod 755 /home/john/datadir
```

### 5. Configure sshd

```bash
vi /etc/ssh/sshd_config
```

Find the existing `Subsystem sftp` line and replace it, then add the `Match` block at the end of the file:

```
# Replace any existing Subsystem sftp line with:
Subsystem sftp internal-sftp

# Apply chroot jail to the sftponly group
Match Group sftponly
    ChrootDirectory %h
    ForceCommand internal-sftp
    X11Forwarding no
    AllowTcpForwarding no
```

> To jail a specific user instead of a group, replace `Match Group sftponly` with `Match User john`.

```bash
systemctl restart sshd.service
```

### 6. Fix SELinux

SELinux blocks chroot home directory access by default. Enable the required boolean:

```bash
setsebool -P ssh_chroot_rw_homedirs on
```

The `-P` flag makes the change persistent across reboots.

---

## Testing

Connect from the same machine:

```bash
sftp john@localhost
```

Once connected, verify the jail is working:

```sftp
sftp> pwd
Remote working directory: /

sftp> ls
datadir

sftp> cd ..
sftp> ls
# Still shows only datadir — cannot escape the jail
```

Upload a test file:

```sftp
sftp> cd datadir
sftp> put testfile.txt
sftp> ls
testfile.txt
```

---

## Permission Reference

| Path | Owner | Permissions | Reason |
|---|---|---|---|
| `/home/john` | `root` | `755` | sshd chroot requirement — must be root-owned |
| `/home/john/datadir` | `john` | `755` | john's writable space inside the jail |

### Permission breakdown

```
755 = rwxr-xr-x

Owner : rwx  — read, write, execute
Group : r-x  — read, execute (no write)
Others: r-x  — read, execute (no write)
```

---

## Key Files

| File | Purpose |
|---|---|
| `/etc/ssh/sshd_config` | Main SSH/SFTP configuration |
| `/etc/ssh/sshd_config.d/` | Drop-in config directory |
| `/home/john/` | Chroot jail root (root-owned) |
| `/home/john/datadir/` | John's writable directory |

---

## Troubleshooting

**Connection refused / Permission denied**
- Confirm `sshd` is running: `systemctl status sshd`
- Check port 22 is open: `ss -tulpn | grep :22`

**Broken pipe / connection drops immediately**
- The chroot directory ownership is wrong. Recheck: `ls -la /home/ | grep john` — owner must be `root`.

**Can connect but cannot write files**
- John is trying to write to `/home/john` directly. He must `cd datadir` first — that is his only writable space.

**SELinux denial**
- Run `setsebool -P ssh_chroot_rw_homedirs on` and restart sshd.
- Check audit log: `tail -f /var/log/audit/audit.log | grep sftp`
