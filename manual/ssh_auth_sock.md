# Manually configuring SSH AUTH SOCK so it works with TMUX & VSCode

Copy the following in `~/.bashrc`:

```bash
export SSH_AUTH_SOCK_ORIGINAL="$SSH_AUTH_SOCK"
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
```

Copy the following in `~/.ssh/rc`:
```bash
#!/bin/bash

if [ ! -S ~/.ssh/ssh_auth_sock ] && [ -S "$SSH_AUTH_SOCK_ORIGINAL" ]; then
  ln -sf $SSH_AUTH_SOCK_ORIGINAL ~/.ssh/ssh_auth_sock
fi
```

Change the permissions to `700`:
```bash
chmod 700 ~/.ssh/rc
```