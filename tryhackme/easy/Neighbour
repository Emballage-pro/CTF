# *Neighbour*

## Recon

Let's begin this new **CTF** with an `nmap` scan, using the command:

```bash
nmap -sC -sV <IP>
```

We can see that port `80` is the only one open, so let's check what we get.

We land on a login page, and we notice that a guest login is available. The credentials can be found in the page source with `Ctrl+U`.

Once connected with the guest account, I tried switching the URL to `admin`, as the CTF hints at an IDOR exploit. By replacing `guest` with `admin` in the URL, I obtained the flag.

> Note: I'm sorry for not providing any screenshots — I wrote this write-up after finishing the room. This is also my first write-up, (so please be indulgent.)
