# Foolmates
## Recon

For this **CTF**, we land directly on a page with an interactive chess board. Luckily, it's White's turn, and there is a checkmate in one by moving the rook to `a8`. But the engine prevents us from delivering this checkmate.

When we try, a fake system popup appears preventing us to win.

## Source code analysis

After checking the page source, we notice two interesting things:

- a hidden banner meant to hold the flag
  

```html
<script type="module" src="js/app.js"></script>
```

Let's look at it directly:
`http://<IP>/js/app.js`
Bingo — we get a big program that contains all the game logic. And here's the key part:

```javascript
function preMoveCheck(from, to, promotion) {
  const probe = new Chess(game.fen());
  let result = probe.move({ from, to, promotion });
  if (result && probe.isCheckmate()) {
    showSystemNotice("I'll shut down your PC if you play that.");
    return false;
  }
  return true;
}
```

The check that blocks the winning move is **entirely client-side**. The script simulates our move, detects the checkmate, shows the fake popup, and cancels the request before it ever reaches the server.

## Exploitation

Since the block only exists in the browser, the fix is simply to bypass it. The mate-in-one is `Ra8#`, so we can send the move straight to the server, skipping the JavaScript filter:

```bash
curl -X POST http://<IP>/api/move \
  -H 'Content-Type: application/json' \
  -d '{"from":"a1","to":"a8"}'
```

The server accepts the move and returns the flag in the JSON response.

